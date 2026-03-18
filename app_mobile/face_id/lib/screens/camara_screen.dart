import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FaceCameraScreen extends StatefulWidget {
  const FaceCameraScreen({super.key});

  @override
  State<FaceCameraScreen> createState() => _FaceCameraScreenState();
}

class _FaceCameraScreenState extends State<FaceCameraScreen> {
  CameraController? _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    _controller = CameraController(frontCam, ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    setState(() {});
  }

  Future<void> _captureAndExtract() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _controller!.takePicture();
      
     
      print("Imagen capturada en: ${image.path}");
      
      _sendToBackend([/* Tus 512 vectores aquí */]);

    } catch (e) {
      print("Error capturando rostro: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _sendToBackend(List<double> embeddings) {
    print("Enviando vectores al servidor...");
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Escaneo Facial"), backgroundColor: Colors.transparent),
      body: Stack(
        alignment: Alignment.center,
        children: [
          CameraPreview(_controller!),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.cyanAccent, width: 2),
              borderRadius: BorderRadius.circular(200),
            ),
            width: 250,
            height: 350,
          ),
          Positioned(
            bottom: 50,
            child: _isProcessing 
              ? const CircularProgressIndicator(color: Colors.cyanAccent)
              : FloatingActionButton.large(
                  onPressed: _captureAndExtract,
                  child: const Icon(Icons.face),
                ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}