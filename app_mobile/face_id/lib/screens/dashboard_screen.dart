import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/load_orchestrator_service.dart';
import 'camera_screen.dart';
// import 'enrollment_screen.dart';
import 'login_screen.dart';
import 'schedules_screen.dart';

class DashboardScreen extends StatefulWidget {
  static const String routeName = '/dashboard';
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _taps = 0;
  bool _isDevMenuVisible = LoadOrchestratorService.instance.isDiagnosticModeEnabled;

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
    final bool isDocente = args['isDocente'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            setState(() {
              if (++_taps >= 5) {
                _isDevMenuVisible = !_isDevMenuVisible;
                LoadOrchestratorService.instance.isDiagnosticModeEnabled = _isDevMenuVisible;
                _taps = 0;
              }
            });
          },
          child: const Text('Dashboard de Control'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded), 
            onPressed: () => Navigator.pushReplacementNamed(context, LoginScreen.routeName)
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Panel de Diagnóstico (Visible solo tras 5 taps)
            if (_isDevMenuVisible) _buildDiagnosticPanel(),
            
            const SizedBox(height: 10),
            
            // Bifurcación de Interfaz por Rol
            if (isDocente) 
              _buildTeacherView() 
            else 
              _buildStudentView(),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.blueGrey.shade200)
      ),
      child: Column(
        children: [
          const Text("PARÁMETROS DE CONFIGURACIÓN DE RED Y HARDWARE", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blueGrey)),
          const SizedBox(height: 16),
          ValueListenableBuilder<OrchestrationMode>(
            valueListenable: LoadOrchestratorService.instance.mode,
            builder: (context, mode, _) => SegmentedButton<OrchestrationMode>(
              segments: const [
                ButtonSegment(value: OrchestrationMode.auto, label: Text('Auto'), icon: Icon(Icons.settings_suggest)),
                ButtonSegment(value: OrchestrationMode.forceEdge, label: Text('Edge'), icon: Icon(Icons.memory)),
                ButtonSegment(value: OrchestrationMode.forceCloud, label: Text('Cloud'), icon: Icon(Icons.cloud_sync)),
              ],
              selected: {mode},
              onSelectionChanged: (val) => LoadOrchestratorService.instance.mode.value = val.first,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: LoadOrchestratorService.instance.hardwareAcceleration,
            builder: (context, enabled, _) => CheckboxListTile(
              title: const Text("Optimización de Precisión por Hardware (NPU)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              subtitle: const Text("Mejora la latencia de inferencia local usando el motor neuronal del dispositivo.", style: TextStyle(fontSize: 10)),
              value: enabled,
              onChanged: (val) => LoadOrchestratorService.instance.hardwareAcceleration.value = val!,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentView() {
    return _buildProfileCard("Héctor Kaleb Martínez", "Perfil: Alumno Activo", [
      _actionButton("REGISTRAR ASISTENCIA", Icons.face_retouching_natural, AppColors.deepBlue, () => _toCamera(context, false)),
    ]);
  }

  Widget _buildTeacherView() {
    return _buildProfileCard("Dra. Lizbeth Geraldine Ibarra", "Perfil: Docente Activo", [
      _actionButton("ENROLAR NUEVO ALUMNO", Icons.person_add_alt_1, AppColors.deepBlue, () => _toCamera(context, true)),
      const SizedBox(height: 12),
      _actionButton("GESTIÓN DE HORARIOS", Icons.edit_calendar_rounded, AppColors.successGreen, () => Navigator.pushNamed(context, SchedulesScreen.routeName)),
    ]);
  }

  Widget _buildProfileCard(String name, String role, List<Widget> actions) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface, 
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.05 * 255).toInt()), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (role.contains("Alumno")) ...[
                const SizedBox(height: 4),
                const Text("Matrícula: TIC-320042", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ]
            ],
          ),
        ),
        const SizedBox(height: 30),
        ...actions,
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback? tap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color, 
        foregroundColor: Colors.white, 
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
      ),
      onPressed: tap,
      icon: Icon(icon, size: 24),
      label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
    );
  }

  void _toCamera(BuildContext context, bool isTeacher) {
    Navigator.pushNamed(context, CameraScreen.routeName, arguments: {
      'mode': isTeacher ? 'enrollment' : 'attendance',
      'name': isTeacher ? 'Nuevo Registro' : 'Héctor Kaleb Martínez',
      'matricula': isTeacher ? 'PENDIENTE' : 'TIC-320042',
      'fromTeacher': isTeacher, // IMPORTANTE: Para que SuccessScreen sepa a dónde volver
    });
  }
}
