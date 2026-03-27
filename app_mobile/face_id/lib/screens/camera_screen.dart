import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'success_screen.dart';

class CameraScreen extends StatefulWidget {
  static const String routeName = '/camera';

  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _showBoundingBox = false;
  bool _isProcessing = false;

  Future<void> _simulateCaptureFlow() async {
    if (_isProcessing) return;
    setState(() {
      _showBoundingBox = true;
    });

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() {
      _isProcessing = true;
    });

    // Simula recorte y generacion de Face Chips 112x112.
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    Navigator.pushNamed(context, SuccessScreen.routeName);

    setState(() {
      _isProcessing = false;
      _showBoundingBox = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Captura de Rostro')),
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
                    color: AppColors.deepBlue.withOpacity(0.25),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEF9),
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                            color: AppColors.successGreen,
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
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: AppColors.deepBlue,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Procesando en Servidor Remoto (Edge)...',
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Generando Face Chips (112x112)',
                                  style: TextStyle(
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
              onPressed: _isProcessing ? null : _simulateCaptureFlow,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Capturar'),
            ),
          ],
        ),
      ),
    );
  }
}
