import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageProcessor {
  ImageProcessor._();
  static final ImageProcessor instance = ImageProcessor._();

  Future<Uint8List> fixOrientation(Uint8List bytes, {int quality = 90}) async {
    return await compute<Map<String, dynamic>, Uint8List>(
      _isolateProcessImage,
      {
        'bytes': bytes,
        'quality': quality,
      },
    );
  }

  Future<Uint8List> compressFaceImage(
    Uint8List bytes, {
    int maxWidth = 720,
    int quality = 80,
  }) async {
    return await compute<Map<String, dynamic>, Uint8List>(
      _isolateCompressImage,
      {
        'bytes': bytes,
        'maxWidth': maxWidth,
        'quality': quality,
      },
    );
  }
}

Uint8List _isolateCompressImage(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'] as Uint8List;
  final int maxWidth = params['maxWidth'] as int? ?? 720;
  final int quality = params['quality'] as int? ?? 80;

  try {
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return bytes;

    img.Image resized = image;
    if (image.width > maxWidth) {
      final int newHeight = (image.height * maxWidth / image.width).round();
      resized = img.copyResize(image, width: maxWidth, height: newHeight);
    }

    final List<int> encoded = img.encodeJpg(resized, quality: quality);
    return Uint8List.fromList(encoded);
  } catch (e) {
    return bytes;
  }
}

Uint8List _isolateProcessImage(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'] as Uint8List;
  final int quality = params['quality'] as int? ?? 90;

  try {
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return bytes;

    final int orientation = _readExifOrientation(bytes);
    img.Image oriented = image;

    switch (orientation) {
      case 3:
        oriented = img.copyRotate(image, angle: 180);
        break;
      case 6:
        oriented = img.copyRotate(image, angle: 90);
        break;
      case 8:
        oriented = img.copyRotate(image, angle: -90);
        break;
    }

    final List<int> encoded = img.encodeJpg(oriented, quality: quality);
    return Uint8List.fromList(encoded);
  } catch (e) {
    return bytes;
  }
}

int _readExifOrientation(Uint8List bytes) {
  try {
    final int len = bytes.length;
    if (len < 4) return 1;
    if (bytes[0] != 0xFF || bytes[1] != 0xD8) return 1;

    int offset = 2;
    while (offset + 4 < len) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }

      final int marker = bytes[offset + 1];
      if (marker == 0xE1) {
        final int size = (bytes[offset + 2] << 8) + bytes[offset + 3];
        if (size < 8) return 1;

        final int headerStart = offset + 4;
        if (headerStart + 5 < len) {
          if (bytes[headerStart] == 0x45 &&
              bytes[headerStart + 1] == 0x78 &&
              bytes[headerStart + 2] == 0x69 &&
              bytes[headerStart + 3] == 0x66 &&
              bytes[headerStart + 4] == 0x00 &&
              bytes[headerStart + 5] == 0x00) {
            
            final int tiffStart = headerStart + 6;
            if (tiffStart + 8 >= len) return 1;

            final ByteData bd = bytes.buffer.asByteData();
            final Endian endian = (bytes[tiffStart] == 0x49 && bytes[tiffStart + 1] == 0x49)
                ? Endian.little
                : Endian.big;

            final int fixed = bd.getUint16(tiffStart + 2, endian);
            if (fixed != 0x002A) return 1;

            final int ifdOffset = bd.getUint32(tiffStart + 4, endian);
            final int ifd0 = tiffStart + ifdOffset;
            if (ifd0 + 2 >= len) return 1;

            final int numEntries = bd.getUint16(ifd0, endian);
            for (int i = 0; i < numEntries; i++) {
              final int entryOffset = ifd0 + 2 + i * 12;
              if (entryOffset + 12 > len) break;

              final int tag = bd.getUint16(entryOffset, endian);
              if (tag == 0x0112) {
                final int type = bd.getUint16(entryOffset + 2, endian);
                final int count = bd.getUint32(entryOffset + 4, endian);

                if (type == 3 && count == 1) {
                  return bd.getUint16(entryOffset + 8, endian);
                } else {
                  final int valueOffset = bd.getUint32(entryOffset + 8, endian);
                  final int actual = tiffStart + valueOffset;
                  if (actual + 2 <= len) {
                    return bd.getUint16(actual, endian);
                  }
                }
              }
            }
            return 1;
          }
        }
        offset += 2 + size;
      } else {
        if (offset + 2 >= len) break;
        final int size = (bytes[offset + 2] << 8) + bytes[offset + 3];
        offset += 2 + size;
      }
    }
  } catch (e) {
    return 1;
  }
  return 1;
}
