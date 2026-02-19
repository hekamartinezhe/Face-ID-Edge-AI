import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const FaceDetectorPage(),
    );
  }
}

class FaceDetectorPage extends StatefulWidget {
  const FaceDetectorPage({super.key});

  @override
  State<FaceDetectorPage> createState() => _FaceDetectorPageState();
}

class _FaceDetectorPageState extends State<FaceDetectorPage> {
  CameraController? _controller;
  FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  bool _isBusy = false;
  CustomPaint? _customPaint;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    // Usamos la cámara frontal para el reconocimiento facial
    final frontCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _controller?.initialize();
    
    // Iniciar el stream de imágenes para detección en tiempo real
    _controller?.startImageStream(_processCameraImage);
    
    if (mounted) setState(() {});
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    final inputImage = _convertCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isNotEmpty) {
      // AQUÍ: Podrías disparar la "toma automática" si el rostro 
      // está centrado en face.boundingBox
      print("¡Rostro detectado!");
    }

    // Dibujar el recuadro visual (opcional)
    if (mounted) {
      setState(() {
        _customPaint = CustomPaint(
          painter: FaceDetectorPainter(
            faces,
            image.height.toDouble(),
            image.width.toDouble(),
          ),
        );
      });
    }

    _isBusy = false;
  }

  // Conversión de formato de cámara a formato de ML Kit
  InputImage? _convertCameraImage(CameraImage image) {
    final sensorOrientation = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front).sensorOrientation;

    final inputImageRotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (inputImageRotation == null) return null;

    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
    if (inputImageFormat == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: inputImageRotation,
        format: inputImageFormat,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Detección de Rostros")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          if (_customPaint != null) _customPaint!,
        ],
      ),
    );
  }
}

// Pintor para dibujar los cuadros sobre los rostros
class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.faces, this.imageHeight, this.imageWidth);

  final List<Face> faces;
  final double imageHeight;
  final double widthScale = 1.0; // Ajustar según el tamaño de la pantalla
  final double imageWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    for (final Face face in faces) {
      // Ajuste de coordenadas para que coincidan con la vista previa
      final double scaleX = size.width / imageWidth;
      final double scaleY = size.height / imageHeight;

      canvas.drawRect(
        Rect.fromLTRB(
          face.boundingBox.left * scaleX,
          face.boundingBox.top * scaleY,
          face.boundingBox.right * scaleX,
          face.boundingBox.bottom * scaleY,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) => true;
}