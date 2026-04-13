import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController();
  final _especialidadCtrl = TextEditingController();
  final _carreraCtrl = TextEditingController();
  final _grupoCtrl = TextEditingController();
  final _materiaCtrl = TextEditingController();
  final _inicioCtrl = TextEditingController();
  final _finCtrl = TextEditingController();
  final _toleranciaCtrl = TextEditingController();
  final _diaCtrl = TextEditingController();
  final _aulaCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isAddingSchedule = false;

  final ApiService _api = ApiService();

  late final UserRole _role;
  late final String _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.user['id']?.toString() ?? widget.user['_id']?.toString() ?? '';
    _role = _parseRole(widget.user['role']?.toString() ?? widget.user['rol']?.toString() ?? 'alumno');
    _nameCtrl.text = widget.user['name']?.toString() ?? widget.user['nombre']?.toString() ?? '';
    _emailCtrl.text = widget.user['email']?.toString() ?? widget.user['correo']?.toString() ?? '';
    _matriculaCtrl.text = widget.user['matricula']?.toString() ?? '';
    _especialidadCtrl.text = widget.user['especialidad']?.toString() ?? '';
    _carreraCtrl.text = widget.user['carrera']?.toString() ?? '';
    _grupoCtrl.text = widget.user['grupo']?.toString() ?? '';
  }

  UserRole _parseRole(String role) {
    return role.toLowerCase() == 'docente' ? UserRole.docente : role.toLowerCase() == 'admin' ? UserRole.admin : UserRole.alumno;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _matriculaCtrl.dispose();
    _especialidadCtrl.dispose();
    _carreraCtrl.dispose();
    _grupoCtrl.dispose();
    _materiaCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    _toleranciaCtrl.dispose();
    _diaCtrl.dispose();
    _aulaCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _api.updateUser(
        id: _userId,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        role: _role,
        password: _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
        matricula: _matriculaCtrl.text.trim().isEmpty ? null : _matriculaCtrl.text.trim(),
        especialidad: _especialidadCtrl.text.trim().isEmpty ? null : _especialidadCtrl.text.trim(),
        carrera: _carreraCtrl.text.trim().isEmpty ? null : _carreraCtrl.text.trim(),
        grupo: _grupoCtrl.text.trim().isEmpty ? null : _grupoCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información actualizada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar usuario: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addSchedule() async {
    if (_materiaCtrl.text.trim().isEmpty || _inicioCtrl.text.trim().isEmpty || _finCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura materia, hora de inicio y fin para la clase')), 
      );
      return;
    }
    setState(() => _isAddingSchedule = true);
    try {
      await _api.addSchedule(
        ownerId: _userId,
        ownerRole: _role == UserRole.docente ? 'docente' : 'alumno',
        materia: _materiaCtrl.text.trim(),
        inicio: _inicioCtrl.text.trim(),
        fin: _finCtrl.text.trim(),
        toleranciaMin: _toleranciaCtrl.text.trim(),
        dia: _diaCtrl.text.trim().isEmpty ? null : _diaCtrl.text.trim(),
        aula: _aulaCtrl.text.trim().isEmpty ? null : _aulaCtrl.text.trim(),
        grupo: _grupoCtrl.text.trim().isEmpty ? null : _grupoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horario/clase agregado correctamente')),
      );
      _materiaCtrl.clear();
      _inicioCtrl.clear();
      _finCtrl.clear();
      _toleranciaCtrl.clear();
      _diaCtrl.clear();
      _aulaCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar horario: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isAddingSchedule = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _role == UserRole.docente ? 'Editar docente' : 'Editar alumno';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre completo'),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Ingresa el nombre' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Correo institucional'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Ingresa el correo';
                      if (!value.contains('@')) return 'Correo no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(labelText: 'Contraseña (dejar en blanco si no cambia)'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 14),
                  if (_role == UserRole.alumno) ...[
                    TextFormField(
                      controller: _matriculaCtrl,
                      decoration: const InputDecoration(labelText: 'Matrícula'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _carreraCtrl,
                      decoration: const InputDecoration(labelText: 'Carrera'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _grupoCtrl,
                      decoration: const InputDecoration(labelText: 'Grupo'),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_role == UserRole.docente) ...[
                    TextFormField(
                      controller: _especialidadCtrl,
                      decoration: const InputDecoration(labelText: 'Especialidad / Materia'),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveUser,
                      child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar información'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Agregar horario / clase',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _materiaCtrl,
              decoration: const InputDecoration(labelText: 'Materia / Clase'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _inicioCtrl,
              decoration: const InputDecoration(labelText: 'Inicio (HH:MM)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _finCtrl,
              decoration: const InputDecoration(labelText: 'Fin (HH:MM)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _toleranciaCtrl,
              decoration: const InputDecoration(labelText: 'Tolerancia en minutos'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _diaCtrl,
              decoration: const InputDecoration(labelText: 'Día'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _aulaCtrl,
              decoration: const InputDecoration(labelText: 'Aula / Grupo'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAddingSchedule ? null : _addSchedule,
                child: _isAddingSchedule
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_role == UserRole.docente ? 'Agregar horario docente' : 'Agregar clase al alumno'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
