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
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _matriculaCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  void _continueToCapture() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pushNamed(
      context,
      CameraScreen.routeName,
      arguments: {
        'mode': 'enrollment',
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
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
                label: 'Nombre completo',
                errorText: 'Captura el nombre del alumno',
              ),
              const SizedBox(height: 10),
              _field(
                controller: _emailCtrl,
                label: 'Correo institucional',
                errorText: 'Captura el correo institucional',
                textInputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              _field(
                controller: _passwordCtrl,
                label: 'Contraseña inicial',
                errorText: 'Captura la contraseña',
                obscureText: true,
              ),
              const SizedBox(height: 10),
              _field(
                controller: _matriculaCtrl,
                label: 'Matrícula',
                errorText: 'Captura la matrícula',
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
                label: const Text('Continuar con captura facial'),
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
    bool obscureText = false,
    TextInputType textInputType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: textInputType,
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
        if (controller == _emailCtrl && !value.contains('@')) return 'Ingresa un correo válido';
        if (controller == _passwordCtrl && value.trim().length < 6) return 'La contraseña debe tener al menos 6 caracteres';
        return null;
      },
    );
  }
}
