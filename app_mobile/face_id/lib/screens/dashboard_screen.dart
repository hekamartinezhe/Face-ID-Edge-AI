import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'camera_screen.dart';
import 'login_screen.dart';
import 'schedules_screen.dart';

class DashboardScreen extends StatelessWidget {
  static const String routeName = '/dashboard';

  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                LoginScreen.routeName,
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesion',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.successGreen,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Conectado a Red Universitaria (IP Validada)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.deepBlue.withOpacity(0.15),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alumno para evidencia',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Hector Kaleb Martinez Hernandez',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Matricula: TIC-320042',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: AppColors.onDeepBlue,
              ),
              onPressed: () => Navigator.pushNamed(context, CameraScreen.routeName),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Ir a Camara'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: AppColors.onSuccessGreen,
              ),
              onPressed: () => Navigator.pushNamed(context, SchedulesScreen.routeName),
              icon: const Icon(Icons.schedule_rounded),
              label: const Text('Gestion de Horarios (Docente)'),
            ),
          ],
        ),
      ),
    );
  }
}
