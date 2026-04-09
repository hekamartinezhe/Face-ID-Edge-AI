import 'dart:convert';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_client.dart';

class TomarAsistenciaScreen extends StatefulWidget {
  const TomarAsistenciaScreen({super.key});

  @override
  State<TomarAsistenciaScreen> createState() => _TomarAsistenciaScreenState();
}

class _TomarAsistenciaScreenState extends State<TomarAsistenciaScreen> {
  CameraController? _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _controller = CameraController(
        frontCam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      _showSnack("Error al iniciar la cámara", isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _capturarYEnviar() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _showSnack("Cámara no inicializada", isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final image = await _controller!.takePicture();
      final imageBytes = await image.readAsBytes();

      // Enviar vía multipart al backend /asistence
      final uri = Uri.parse('${ApiClient.instance.baseUrl}/asistence');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'face.jpg'));

      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['resultado'] == 'reconocido') {
          // Navegar a éxito
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SuccessScreen(alumno: data['nombre'], confianza: data['confianza']),
            ),
          );
        } else {
          // Navegar a error
          String mensaje = 'No identificado';
          if (data.containsKey('error')) {
            mensaje = data['error'];
          }
          if (data.containsKey('mensaje')) {
            mensaje += '\n\n' + data['mensaje'];
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ErrorScreen(mensaje: mensaje),
            ),
          );
        }
      } else {
        _showSnack("Error en el servidor: ${resp.statusCode}", isError: true);
      }
    } catch (e) {
      _showSnack("Error al procesar: $e", isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tomar Asistencia')),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(_controller!),
                // Overlay con instrucciones
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '📸 Instrucciones:\n• Mira directamente a la cámara\n• Asegúrate de buena iluminación\n• Mantén el rostro centrado\n• Evita lentes o sombreros',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _capturarYEnviar,
                      child: const Text('Capturar'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class SuccessScreen extends StatelessWidget {
  final String alumno;
  final double confianza;

  const SuccessScreen({super.key, required this.alumno, required this.confianza});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Éxito')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            Text('Alumno identificado: $alumno'),
            Text('Confianza: ${confianza.toStringAsFixed(2)}'),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String mensaje;

  const ErrorScreen({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 100),
              const SizedBox(height: 20),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}