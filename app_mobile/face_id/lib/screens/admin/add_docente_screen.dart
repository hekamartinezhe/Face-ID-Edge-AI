import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../services/api_service.dart';

class AddDocenteScreen extends StatefulWidget {
  const AddDocenteScreen({super.key});

  @override
  State<AddDocenteScreen> createState() => _AddDocenteScreenState();
}

class _AddDocenteScreenState extends State<AddDocenteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _especialidadCtrl = TextEditingController();
  final ApiService _api = ApiService();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _especialidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDocente() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await _api.registerDocente(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        especialidad: _especialidadCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Docente agregado correctamente')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar docente: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Docente')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Ingresa el nombre del docente' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Correo institucional'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Ingresa el correo del docente';
                  if (!value.contains('@')) return 'Correo no válido';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña inicial'),
                obscureText: true,
                validator: (value) => (value == null || value.trim().length < 6) ? 'La contraseña debe tener al menos 6 caracteres' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _especialidadCtrl,
                decoration: const InputDecoration(labelText: 'Especialidad / Materia'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Ingresa la especialidad' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDocente,
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar docente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
