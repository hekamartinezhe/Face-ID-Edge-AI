import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../app_colors.dart';
import '../models/recognition_result.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/image_processor.dart';
import '../services/load_orchestrator_service.dart';
import 'dashboard_screen.dart';
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

  final List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  String _getLoadingText() {
    final mode = LoadOrchestratorService.instance.mode.value;
    switch (mode) {
      case OrchestrationMode.forceEdge:
        return 'Procesando en NPU Local...';
      case OrchestrationMode.forceCloud:
        return 'Conectando al Servidor...';
      default:
        return 'Orquestando inferencia...';
    }
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
      _availableCameras.clear();
      _availableCameras.addAll(cameras);
      _selectedCameraIndex = cameras.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
          ) >=
          0
          ? cameras.indexWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front,
            )
          : 0;
      await _initializeCameraController(_availableCameras[_selectedCameraIndex]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'No fue posible iniciar la camara.';
      });
    }
  }

  Future<void> _initializeCameraController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _cameraError = null;
      });
    } on CameraException catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _cameraError = 'Error al iniciar la cámara: ${e.description}';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isProcessing) return;
    final nextIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    setState(() {
      _cameraReady = false;
      _cameraError = null;
    });
    await _cameraController?.dispose();
    _selectedCameraIndex = nextIndex;
    await _initializeCameraController(_availableCameras[_selectedCameraIndex]);
  }

  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();

  Future<void> _simulateCaptureFlow() async {
    if (_isProcessing || !_cameraReady) return;
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
            {};
    final String mode = (args['mode'] as String?) ?? 'attendance';
    final bool isEnrollment = mode == 'enrollment';
    final bool isLoginFace = mode == 'login-face';
    final String matricula = args['matricula'] as String? ?? 'TIC-000000';
    final String enrollmentName = args['name'] as String? ?? 'Desconocido';

    setState(() {
      _showBoundingBox = true;
      _isProcessing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      final Uint8List fileBytes = await File(image.path).readAsBytes();
      final Uint8List orientedBytes = await ImageProcessor.instance.fixOrientation(fileBytes);
      final Uint8List processedBytes = await ImageProcessor.instance.compressFaceImage(
        orientedBytes,
        maxWidth: 720,
        quality: 80,
      );

      if (isLoginFace) {
        await _auth.loginWithFace(processedBytes);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, DashboardScreen.routeName);
        return;
      }

      RecognitionResult result;
      if (isEnrollment) {
        final email = args['email'] as String? ?? '';
        final password = args['password'] as String? ?? '';
        final group = args['group'] as String? ?? '';

        final alumno = await _api.registerAlumno(
          name: enrollmentName,
          email: email,
          password: password,
          matricula: matricula,
          faceImage: processedBytes,
          grupo: group,
        );

        result = RecognitionResult(
          status: 'ok',
          match: true,
          label: alumno.name,
          confidence: 0.96,
          message: 'Registro facial completado',
        );
      } else {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception('Usuario no autenticado');
        }
        final claseId = args['claseId'] as String? ?? args['group'] as String? ?? 'clase-desconocida';

        final response = await _api.registrarAsistencia(
          alumnoId: currentUser.id,
          claseId: claseId,
          faceImage: processedBytes,
        );

        final String mensaje = response['message']?.toString() ?? 'Asistencia registrada';
        final bool match = response['status']?.toString().toLowerCase() == 'ok' ||
            response['status']?.toString().toLowerCase() == 'success';

        result = RecognitionResult(
          status: response['status']?.toString() ?? 'ok',
          match: match,
          label: currentUser.name,
          confidence: (response['confidence'] as num?)?.toDouble() ?? 0.94,
          assistance: true,
          message: mensaje,
        );
      }

      setState(() {
        _boxColor = result.match ? AppColors.successGreen : Colors.redAccent;
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        SuccessScreen.routeName,
        arguments: {
          'result': result,
          'mode': InferenceMode.cloud,
          'latency': 0,
          'matricula': matricula,
          'fromTeacher': false,
        },
      );
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
    final bool isLoginFace = mode == 'login-face';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEnrollment
              ? 'Enrolamiento Biometrico'
              : isLoginFace
                  ? 'Ingreso con rostro'
                  : 'Registro de Asistencia',
        ),
        actions: [
          if (_availableCameras.length > 1)
            IconButton(
              icon: Icon(
                _availableCameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front
                    ? Icons.camera_front_rounded
                    : Icons.camera_rear_rounded,
              ),
              onPressed: _switchCamera,
              tooltip: 'Cambiar cámara',
            ),
        ],
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
                                Text(
                                  _getLoadingText(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
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
              label: Text(isEnrollment
                  ? 'Capturar y registrar'
                  : isLoginFace
                      ? 'Ingresar con rostro'
                      : 'Capturar asistencia'),
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
