import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'camera_screen.dart';
import 'dashboard_screen.dart';

class SuccessScreen extends StatelessWidget {
  static const String routeName = '/success';

  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final horaActual =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado de Asistencia')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 18),
            const Icon(
              Icons.verified_rounded,
              size: 88,
              color: AppColors.successGreen,
            ),
            const SizedBox(height: 14),
            const Text(
              'Reconocimiento Exitoso',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asistencia registrada: Hector Kaleb Martinez Hernandez - $horaActual',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Matricula: TIC-320042',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Estatus: Presente',
                    style: TextStyle(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: AppColors.onDeepBlue,
              ),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  DashboardScreen.routeName,
                  (route) => false,
                );
              },
              icon: const Icon(Icons.dashboard_rounded),
              label: const Text('Volver al Dashboard'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: AppColors.onSuccessGreen,
              ),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  CameraScreen.routeName,
                  (route) => false,
                );
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Nueva Captura'),
            ),
          ],
        ),
      ),
    );
  }
}
