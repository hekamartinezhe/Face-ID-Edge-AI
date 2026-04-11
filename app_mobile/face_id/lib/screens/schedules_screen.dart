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

  Future<void> _saveSchedule() async {
    // E1: Campos incompletos
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Campos incompletos. Complete los campos requeridos.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    // Convertir a minutos y validar formato
    final start = _toMinutes(_inicioCtrl.text.trim());
    final end = _toMinutes(_finCtrl.text.trim());
    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Formato de hora inválido. Use HH:MM.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    // E2: Horario inválido (fin debe ser estrictamente mayor a inicio)
    if (end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Horario inválido: la Hora de Fin debe ser mayor que la Hora de Inicio.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    final materia = _materiaCtrl.text.trim();
    // E4: Conflicto simulado
    if (materia == 'Inteligencia Artificial' && _inicioCtrl.text.trim() == '08:00') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Conflicto de horarios superpuestos'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    // E3: Simulación de llamada asíncrona que falla (servidor caído)
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final simulateNetworkDown = DateTime.now().microsecondsSinceEpoch > 0;
      if (simulateNetworkDown) throw Exception('Simulated server down');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error de conexión. Reintente más tarde.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      // NO limpiar controladores para que los datos ingresados se mantengan
      return;
    }

    // Si llegamos aquí, se habría guardado correctamente (no sucede en demo)
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Horario actualizado correctamente.'),
        backgroundColor: Colors.green,
      ),
    );

    // Limpiar campos después del guardado exitoso
    _materiaCtrl.clear();
    _inicioCtrl.clear();
    _finCtrl.clear();
    _tolCtrl.clear();
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
        border: Border.all(color: AppColors.deepBlue.withAlpha((0.12 * 255).toInt())),
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
