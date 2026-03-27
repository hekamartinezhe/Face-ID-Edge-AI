import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'camera_screen.dart';

class EnrollmentScreen extends StatefulWidget {
  static const String routeName = '/enrollment';

  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _matriculaCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  void _continueToCapture() {
    if (!_formKey.currentState!.validate()) return;

    if (_matriculaCtrl.text.trim().toUpperCase() == 'TIC-320042') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Matricula duplicada: el alumno ya existe.'),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      CameraScreen.routeName,
      arguments: {
        'mode': 'enrollment',
        'name': _nameCtrl.text.trim(),
        'matricula': _matriculaCtrl.text.trim(),
        'group': _groupCtrl.text.trim(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enrolamiento Biometrico')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Registro de nuevo alumno',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepBlue,
                ),
              ),
              const SizedBox(height: 14),
              _field(
                controller: _nameCtrl,
                label: 'Nombre',
                errorText: 'Captura el nombre del alumno',
              ),
              const SizedBox(height: 10),
              _field(
                controller: _matriculaCtrl,
                label: 'Matricula',
                errorText: 'Captura la matricula',
              ),
              const SizedBox(height: 10),
              _field(
                controller: _groupCtrl,
                label: 'Grupo',
                errorText: 'Captura el grupo',
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBlue,
                  foregroundColor: AppColors.onDeepBlue,
                ),
                onPressed: _continueToCapture,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Continuar a Captura Facial'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String errorText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return errorText;
        return null;
      },
    );
  }
}
