import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'camera_screen.dart';
import 'enrollment_screen.dart';
import 'login_screen.dart';
import 'schedules_screen.dart';

class DashboardScreen extends StatelessWidget {
  static const String routeName = '/dashboard';

  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
            {};
    final bool isDocente = args['isDocente'] == true;
    final String actorLabel = isDocente ? 'Docente activo' : 'Alumno activo';
    final String actorName = isDocente
        ? 'Lizbeth Geraldine Ibarra Carlos'
        : 'Hector Kaleb Martinez Hernandez';

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actorLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    actorName,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (!isDocente) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Matricula: TIC-320042',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: AppColors.onDeepBlue,
              ),
              onPressed: () => Navigator.pushNamed(
                context,
                CameraScreen.routeName,
                arguments: {'mode': 'attendance'},
              ),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Registrar Asistencia'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: AppColors.onDeepBlue,
              ),
              onPressed: isDocente
                  ? () => Navigator.pushNamed(context, EnrollmentScreen.routeName)
                  : null,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Registrar Nuevo Alumno'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: AppColors.onSuccessGreen,
              ),
              onPressed: isDocente
                  ? () => Navigator.pushNamed(context, SchedulesScreen.routeName)
                  : null,
              icon: const Icon(Icons.schedule_rounded),
              label: const Text('Gestion de Horarios (Docente)'),
            ),
            if (!isDocente) ...[
              const SizedBox(height: 8),
              const Text(
                'Activa perfil Docente en login para habilitar Gestion.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
