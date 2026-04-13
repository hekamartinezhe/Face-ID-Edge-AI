// ignore_for_file: use_build_context_synchronously, prefer_interpolation_to_compose_strings, unused_import
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

/// Pantalla para tomar asistencia con reconocimiento facial
/// Figura 20 (Puntual), Figura 21 (Retardo), Figura 22 (No reconocido)
class TomarAsistenciaScreen extends StatefulWidget {
  final UserModel user;
  final Map<String, dynamic> clase;

  const TomarAsistenciaScreen({
    super.key,
    required this.user,
    required this.clase,
  });

  @override
  State<TomarAsistenciaScreen> createState() => _TomarAsistenciaScreenState();
}

class _TomarAsistenciaScreenState extends State<TomarAsistenciaScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _showResult = false;
  String _resultStatus = ''; // 'puntual', 'retardo', 'no_reconocido'
  double _confianza = 0.0;

  final ApiService _api = ApiService();

  // Detector de rostros
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initCamera();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
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
      if (!mounted) return;
      _showSnack("Error al iniciar la cámara", isError: true);
    }
  }

  Future<void> _tomarAsistencia() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // 1. Tomar foto
      final image = await _controller!.takePicture();

      // 2. Validar rostro
      final isFaceValid = await _validateFaceQuality(image);
      if (!isFaceValid) {
        setState(() => _isProcessing = false);
        return;
      }

      // 3. Enviar a API para reconocimiento y asistencia
      final bytes = await image.readAsBytes();

      final response = await _api.registrarAsistencia(
        alumnoId: widget.user.id,
        claseId: widget.clase['id']?.toString() ?? widget.clase['materia'],
        faceImage: bytes,
      );

      final now = DateTime.now();
      final horaInicio = _parseHora(widget.clase['horaInicio']);
      final diferencia = now.difference(horaInicio);
      final bool reconocido = response['status']?.toString().toLowerCase() == 'ok' ||
          response['status']?.toString().toLowerCase() == 'success';
      final double confianza = (response['confidence'] as num?)?.toDouble() ?? 0.95;
      final String mensaje = response['message']?.toString() ?? 'Asistencia registrada';

      if (!mounted) return;
      setState(() {
        _confianza = confianza;
        if (!reconocido) {
          _resultStatus = 'no_reconocido';
        } else if (diferencia.inMinutes > 15) {
          _resultStatus = 'retardo';
        } else {
          _resultStatus = 'puntual';
        }
        _showResult = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack("Error: $e", isError: true);
      setState(() => _isProcessing = false);
    }
  }

  Future<bool> _validateFaceQuality(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      if (!mounted) return false;
      _showSnack("No se detectó ningún rostro", isError: true);
      return false;
    }
    if (faces.length > 1) {
      if (!mounted) return false;
      _showSnack("Hay más de una persona en cámara", isError: true);
      return false;
    }

    final face = faces.first;

    if ((face.headEulerAngleY ?? 0).abs() > 20) {
      if (!mounted) return false;
      _showSnack("Mira directamente a la cámara", isError: true);
      return false;
    }

    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    if (leftEye == null || rightEye == null || leftEye < 0.5 || rightEye < 0.5) {
      if (!mounted) return false;
      _showSnack("Ojos no visibles", isError: true);
      return false;
    }

    return true;
  }

  DateTime _parseHora(String horaStr) {
    final now = DateTime.now();
    final parts = horaStr.split(':');
    return DateTime(now.year, now.month, now.day, 
                    int.parse(parts[0]), int.parse(parts[1]));
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'TOMAR ASISTENCIA',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _showResult ? _buildResultView() : _buildCameraView(),
    );
  }

  Widget _buildCameraView() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vista de cámara
              CameraPreview(_controller!),
              
              // Overlay oscuro
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha((0.7 * 255).toInt()),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              
              // Marco facial animado
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isProcessing ? 1.0 : _pulseAnimation.value,
                    child: Container(
                      width: 250,
                      height: 320,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isProcessing ? Colors.yellow : Colors.cyanAccent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(160),
                        boxShadow: [
                          BoxShadow(
                            color: (_isProcessing ? Colors.yellow : Colors.cyanAccent)
                                .withAlpha((0.3 * 255).toInt()),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              // Indicador de procesamiento
              if (_isProcessing)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.cyanAccent,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Reconociendo...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        // Información de la clase
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3799),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.clase['materia'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.clase['horaInicio']} - ${widget.clase['horaFin']} | ${widget.clase['aula']}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _tomarAsistencia,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt),
                    label: Text(_isProcessing ? 'PROCESANDO...' : 'CAPTURAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    switch (_resultStatus) {
      case 'puntual':
        return _buildSuccessResult(
          icon: Icons.check_circle,
          color: Colors.green,
          title: 'ASISTENCIA REGISTRADA',
          subtitle: '¡Bienvenido!',
          message: 'Tu asistencia ha sido registrada correctamente.',
          confianza: _confianza,
        );
      case 'retardo':
        return _buildSuccessResult(
          icon: Icons.watch_later,
          color: Colors.orange,
          title: 'ASISTENCIA CON RETARDO',
          subtitle: 'Llegaste tarde',
          message: 'Tu asistencia fue registrada con retardo.',
          confianza: _confianza,
        );
      case 'no_reconocido':
        return _buildErrorResult();
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildSuccessResult({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String message,
    required double confianza,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withAlpha((0.1 * 255).toInt()),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
            ),
            child: Icon(icon, size: 80, color: color),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Confianza: ${(confianza * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'VOLVER A MI HORARIO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha((0.1 * 255).toInt()),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red, width: 3),
            ),
            child: const Icon(Icons.error_outline, size: 80, color: Colors.red),
          ),
          const SizedBox(height: 32),
          const Text(
            'NO RECONOCIDO',
            style: TextStyle(
              color: Colors.red,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Rostro no identificado',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No pudimos reconocer tu rostro. Intenta nuevamente o contacta a tu docente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Confianza: 0.0%',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _showResult = false;
                  _isProcessing = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'INTENTAR NUEVAMENTE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'VOLVER A MI HORARIO',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _faceDetector.close();
    _controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }
}