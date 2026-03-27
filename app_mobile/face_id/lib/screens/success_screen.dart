import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'camera_screen.dart';
import 'dashboard_screen.dart';

class SuccessScreen extends StatelessWidget {
  static const String routeName = '/success';

  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
            {};
    final String mode = (args['mode'] as String?) ?? 'attendance';
    final String status = (args['status'] as String?) ?? 'Presente';
    final String name =
        (args['name'] as String?) ?? 'Hector Kaleb Martinez Hernandez';
    final String matricula = (args['matricula'] as String?) ?? 'TIC-320042';
    final bool isEnrollment = mode == 'enrollment';

    final now = TimeOfDay.now();
    final horaActual =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEnrollment ? 'Resultado de Enrolamiento' : 'Resultado de Asistencia',
        ),
      ),
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
              'Operacion Exitosa',
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
                    isEnrollment
                        ? 'Alumno registrado correctamente: $name'
                        : 'Asistencia registrada: $name - $horaActual',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Matricula: $matricula',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isEnrollment ? 'Estatus: Enrolado' : 'Estatus: $status',
                    style: TextStyle(
                      color: status == 'Retardo'
                          ? const Color(0xFFF2C94C)
                          : AppColors.successGreen,
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
