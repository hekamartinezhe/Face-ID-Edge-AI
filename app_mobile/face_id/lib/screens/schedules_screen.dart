import 'package:flutter/material.dart';
import '../app_colors.dart';

class SchedulesScreen extends StatelessWidget {
  static const String routeName = '/schedules';

  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion de Horarios')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Formulario Docente',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildField('Materia'),
                  const SizedBox(height: 10),
                  _buildField('Hora de Inicio'),
                  const SizedBox(height: 10),
                  _buildField('Hora de Fin'),
                  const SizedBox(height: 10),
                  _buildField('Minutos de Tolerancia'),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepBlue,
                      foregroundColor: AppColors.onDeepBlue,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Horario mock guardado para evidencia'),
                        ),
                      );
                    },
                    child: const Text('Guardar Horario'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Materias Programadas (Mock)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: 10),
            _buildSubjectTile(
              title: 'Inteligencia Artificial',
              subtitle: '08:00 - 10:00 | Tolerancia: 10 min',
            ),
            const SizedBox(height: 8),
            _buildSubjectTile(
              title: 'Redes',
              subtitle: '10:00 - 12:00 | Tolerancia: 15 min',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSubjectTile({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.deepBlue.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, color: AppColors.deepBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
