import 'dart:typed_data';
import 'dart:math';
import 'dart:typed_data' as u;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// ImageProcessor
/// - Ejecuta la corrección de orientación EXIF en un Isolate usando `compute`.
/// - Entrada: `Uint8List` con bytes de la imagen (JPEG/PNG).
/// - Salida: `Uint8List` listo para enviar al backend.
class ImageProcessor {
  ImageProcessor._();
  static final ImageProcessor instance = ImageProcessor._();

  /// Corrige la orientación basándose en la etiqueta EXIF y re-encodea la imagen.
  /// Se ejecuta en un Isolate para no bloquear la UI (recomendado para S23 Ultra).
  Future<Uint8List> fixOrientation(Uint8List bytes, {int quality = 90}) async {
    final result = await compute(_isolateProcessImage, <String, dynamic>{
      'bytes': bytes,
      'quality': quality,
    });

    return result as Uint8List;
  }
}

// Top-level isolate entrypoint (necesario para `compute`).
Uint8List _isolateProcessImage(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'] as Uint8List;
  final int quality = params['quality'] as int? ?? 90;

  try {
    // Decode image using package:image
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Leer orientación EXIF (1 = default)
    final int orientation = _readExifOrientation(bytes);

    img.Image oriented = image;

    switch (orientation) {
      case 3:
        oriented = img.copyRotate(image, 180);
        break;
      case 6:
        oriented = img.copyRotate(image, 90);
        break;
      case 8:
        oriented = img.copyRotate(image, -90);
        break;
      default:
        // 1 or unknown -> no-op
        break;
    }

    // Re-encode as JPEG (compatible con ApiClient MultipartFile)
    final List<int> encoded = img.encodeJpg(oriented, quality: quality);
    return Uint8List.fromList(encoded);
  } catch (e) {
    // En caso de error, devolver bytes originales para no bloquear flujo.
    return bytes;
  }
}

/// Parser EXIF mínimo para obtener la etiqueta Orientation (0x0112).
/// Retorna 1 si no encuentra la etiqueta o en caso de error.
int _readExifOrientation(Uint8List bytes) {
  try {
    final int len = bytes.length;
    if (len < 4) return 1;

    // JPEG SOI
    if (bytes[0] != 0xFF || bytes[1] != 0xD8) return 1;

    int offset = 2;

    while (offset + 4 < len) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }

      final int marker = bytes[offset + 1];

      // APP1 marker (EXIF)
      if (marker == 0xE1) {
        final int size = (bytes[offset + 2] << 8) + bytes[offset + 3];
        if (size < 8) return 1;

        final int headerStart = offset + 4;
        if (headerStart + 5 < len) {
          // "Exif\0\0"
          if (bytes[headerStart] == 0x45 &&
              bytes[headerStart + 1] == 0x78 &&
              bytes[headerStart + 2] == 0x69 &&
              bytes[headerStart + 3] == 0x66 &&
              bytes[headerStart + 4] == 0x00 &&
              bytes[headerStart + 5] == 0x00) {

            final int tiffStart = headerStart + 6;
            if (tiffStart + 8 >= len) return 1;

            final u.ByteData bd = bytes.buffer.asByteData();

            // Endianness
            final int byteOrder = bd.getUint16(tiffStart, Endian.big);
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

                // If value fits in 4 bytes, it's stored inline
                if (type == 3 && count == 1) {
                  final int value = bd.getUint16(entryOffset + 8, endian);
                  return value;
                } else {
                  final int valueOffset = bd.getUint32(entryOffset + 8, endian);
                  final int actual = tiffStart + valueOffset;
                  if (actual + 2 <= len) {
                    final int value = bd.getUint16(actual, endian);
                    return value;
                  }
                }
              }
            }
            return 1;
          }
        }
        offset += 2 + size;
      } else {
        // Other marker, skip
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
