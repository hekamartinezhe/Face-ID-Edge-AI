import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Nueva importación

class FaceCameraScreen extends StatefulWidget {
  const FaceCameraScreen({super.key});

  @override
  State<FaceCameraScreen> createState() => _FaceCameraScreenState();
}

class _FaceCameraScreenState extends State<FaceCameraScreen> {
  CameraController? _controller;
  bool _isProcessing = false;

  // Configuración de la API (Cambia localhost por tu IP si pruebas en físico)
  final String apiUrl = "http://100.119.64.47:8800"; // 10.0.2.2 es el localhost del emulador Android

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

  // Simulación de extracción de vectores (Aquí deberías usar tu modelo TFLite o similar)
  List<double> _mockVectorExtraction() {
    return List<double>.generate(512, (index) => 0.123); // Simula 512 valores
  }

  Future<void> _captureAndExtract() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // 1. Capturar imagen
      final image = await _controller!.takePicture();
      print("Imagen capturada: ${image.path}");
      
      // 2. Extraer vectores (Este paso depende de tu implementación de On-Device AI)
      final embeddings = _mockVectorExtraction();
      
      // 3. Enviar a la API de FastAPI
      await _sendToBackend(embeddings);

    } catch (e) {
      _showSnack("Error: $e", isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _sendToBackend(List<double> embeddings) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/assistance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vector': embeddings,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (result['match'] == true) {
          _showSnack("✅ Bienvenida/o: ${result['user']} (Confianza: ${(result['confidence'] * 100).toStringAsFixed(1)}%)");
        } else {
          _showSnack("🚫 Rostro no reconocido", isError: true);
        }
      } else {
        _showSnack("❌ Error del servidor: ${result['detail']}", isError: true);
      }
    } catch (e) {
      _showSnack("📡 Error de conexión con la API", isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Escaneo Facial"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          CameraPreview(_controller!),
          // Overlay de escaneo
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isProcessing ? Colors.yellow : Colors.cyanAccent, 
                width: 3
              ),
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
                  backgroundColor: Colors.cyanAccent,
                  onPressed: _captureAndExtract,
                  child: const Icon(Icons.face, color: Colors.black, size: 40),
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