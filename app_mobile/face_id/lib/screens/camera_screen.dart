import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../app_colors.dart';
import '../services/image_processor.dart';
import '../services/load_orchestrator_service.dart';
import 'success_screen.dart';

class CameraScreen extends StatefulWidget {
  static const String routeName = '/camera';

  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  bool _cameraReady = false;
  String? _cameraError;
  bool _showBoundingBox = false;
  bool _isProcessing = false;
  Color _boxColor = AppColors.successGreen;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'No se detecto ninguna camara disponible.';
        });
        return;
      }
      final frontCam = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'No fue posible iniciar la camara.';
      });
    }
  }

  Future<void> _simulateCaptureFlow() async {
    if (_isProcessing || !_cameraReady) return;
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
            {};
    final String mode = (args['mode'] as String?) ?? 'attendance';
    final bool isEnrollment = mode == 'enrollment';
    final String enrollmentName = args['name'] as String? ?? 'Desconocido';
    final String matricula = args['matricula'] as String? ?? 'TIC-000000';

    setState(() {
      _showBoundingBox = true;
      _isProcessing = true;
    });

    try {
      // 1. Capturar imagen
      final XFile image = await _cameraController!.takePicture();

      // 2. Leer bytes y corregir orientación en Isolate usando ImageProcessor
      final Uint8List fileBytes = await File(image.path).readAsBytes();
      final Uint8List processedBytes = await ImageProcessor.instance.fixOrientation(fileBytes);

      // 3. Enviar a Orquestador (Edge vs Cloud)
      final orchestration = await LoadOrchestratorService.instance.processFace(
        processedBytes,
        isEnrollment: isEnrollment,
        name: enrollmentName,
      );

      setState(() {
        _boxColor = orchestration.result.match ? AppColors.successGreen : Colors.redAccent;
      });

      // Pequeña pausa para mostrar badge/feedback
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      if (orchestration.result.status == 'error' || !orchestration.result.match) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${orchestration.result.message ?? "Rostro desconocido"}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        final now = TimeOfDay.now();
        final bool isRetardo = !isEnrollment && now.minute > 15;
        Navigator.pushReplacementNamed(
          context,
          SuccessScreen.routeName,
          arguments: {
            'mode': mode,
            'status': isEnrollment ? 'Enrolado' : (isRetardo ? 'Retardo' : 'Presente'),
            'name': orchestration.result.label ?? enrollmentName,
            'matricula': matricula,
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _showBoundingBox = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
            {};
    final String mode = (args['mode'] as String?) ?? 'attendance';
    final bool isEnrollment = mode == 'enrollment';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEnrollment ? 'Enrolamiento Biometrico' : 'Registro de Asistencia',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.deepBlue.withAlpha((0.25 * 255).toInt()),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(14),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _buildCameraLayer(),
                    ),
                    // Overlay circular de alineacion.
                    IgnorePointer(
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.deepBlue,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.deepBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Alinee el rostro en el circulo',
                          style: TextStyle(
                            color: AppColors.onDeepBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (_showBoundingBox)
                      Container(
                        width: 170,
                        height: 210,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _boxColor,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    if (_isProcessing)
                      Container(
                        color: Colors.black45,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: AppColors.deepBlue,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Procesando en Servidor Remoto (Edge)...',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isEnrollment
                                      ? 'Generando Face Chips (112x112)'
                                      : 'Comparando embeddings en servidor',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: AppColors.onDeepBlue,
              ),
              onPressed: (_isProcessing || !_cameraReady)
                  ? null
                  : _simulateCaptureFlow,
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(isEnrollment ? 'Capturar Rafaga' : 'Capturar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_cameraError != null) {
      return Center(
        child: Text(
          _cameraError!,
          style: const TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (!_cameraReady || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.deepBlue),
      );
    }
    return CameraPreview(_cameraController!);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
