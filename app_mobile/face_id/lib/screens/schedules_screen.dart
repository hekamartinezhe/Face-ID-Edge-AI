import 'package:flutter/material.dart';
import '../app_colors.dart';

class SchedulesScreen extends StatefulWidget {
  static const String routeName = '/schedules';

  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _materiaCtrl = TextEditingController();
  final _inicioCtrl = TextEditingController();
  final _finCtrl = TextEditingController();
  final _tolCtrl = TextEditingController();

  @override
  void dispose() {
    _materiaCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    _tolCtrl.dispose();
    super.dispose();
  }

  void _saveSchedule() {
    if (!_formKey.currentState!.validate()) return;

    final start = _toMinutes(_inicioCtrl.text.trim());
    final end = _toMinutes(_finCtrl.text.trim());
    if (start == null || end == null || end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Horario invalido: la hora de fin debe ser mayor.'),
        ),
      );
      return;
    }

    final materia = _materiaCtrl.text.trim().toLowerCase();
    if (materia == 'inteligencia artificial' && _inicioCtrl.text.trim() == '08:00') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conflicto detectado con un horario existente.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Horario actualizado correctamente.'),
      ),
    );
  }

  int? _toMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion de Horarios')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _formKey,
              child: Container(
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
                    _buildField(_materiaCtrl, 'Materia'),
                    const SizedBox(height: 10),
                    _buildField(_inicioCtrl, 'Hora de Inicio (HH:MM)'),
                    const SizedBox(height: 10),
                    _buildField(_finCtrl, 'Hora de Fin (HH:MM)'),
                    const SizedBox(height: 10),
                    _buildField(_tolCtrl, 'Minutos de Tolerancia'),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepBlue,
                        foregroundColor: AppColors.onDeepBlue,
                      ),
                      onPressed: _saveSchedule,
                      child: const Text('Guardar Horario'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Materias Programadas',
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

  Widget _buildField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Campo obligatorio';
        }
        return null;
      },
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
