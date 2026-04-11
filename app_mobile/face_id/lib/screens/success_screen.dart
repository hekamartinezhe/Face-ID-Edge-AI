import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/recognition_result.dart';
import '../services/load_orchestrator_service.dart';
import 'dashboard_screen.dart';

class SuccessScreen extends StatelessWidget {
  static const String routeName = '/success';

  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
    
    final RecognitionResult result = args['result'];
    final InferenceMode mode = args['mode'] ?? InferenceMode.edge;
    final String matricula = args['matricula'] ?? 'TIC-XXXXXX';
    final int latency = args['latency'] ?? 0;

    final now = DateTime.now();
    final String horaActual = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final String status = result.message ?? 'Presente';
    final double confidence = (result.confidence ?? 0.0) * 100;
    final bool fromTeacher = (args['fromTeacher'] as bool?) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.verified_rounded, size: 100, color: AppColors.successGreen),
            const SizedBox(height: 16),
            const Text(
              '¡Registro Exitoso!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.deepBlue),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Alumno', result.label ?? 'Desconocido', isTitle: true),
                  _infoRow('Matrícula', matricula),
                  _infoRow('Hora de Registro', horaActual),
                  const Divider(height: 30),
                  Row(
                    children: [
                      _statusBadge(status),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Confianza: ${confidence.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBlue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (mode == InferenceMode.edge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.deepBlue.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.memory, size: 16, color: AppColors.deepBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Inferencia procesada en Edge AI (${latency}ms)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.deepBlue),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                DashboardScreen.routeName,
                (r) => false,
                arguments: {'isDocente': fromTeacher},
              ),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepBlue, foregroundColor: Colors.white),
              child: const Text('Volver al Inicio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isTitle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: isTitle ? 18 : 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final bool isRetardo = status == 'Retardo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
        color: isRetardo ? Colors.orange.withAlpha((0.2 * 255).toInt()) : AppColors.successGreen.withAlpha((0.2 * 255).toInt()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isRetardo ? Colors.orange : AppColors.successGreen),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: isRetardo ? Colors.orange.shade900 : AppColors.successGreen, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
