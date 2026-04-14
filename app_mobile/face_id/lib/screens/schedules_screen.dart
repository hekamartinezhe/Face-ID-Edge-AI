import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class SchedulesScreen extends StatefulWidget {
  static const String routeName = '/schedules';

  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _materiaCtrl = TextEditingController();
  final _inicioCtrl = TextEditingController();
  final _finCtrl = TextEditingController();
  final _tolCtrl = TextEditingController();
  final _diaCtrl = TextEditingController();
  final _aulaCtrl = TextEditingController();
  final _grupoCtrl = TextEditingController();
  final List<Map<String, String>> _horarios = [];

  bool _isLoadingDocentes = true;
  List<UserModel> _docentes = [];
  UserModel? _selectedDocente;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDocentes();
  }

  @override
  void dispose() {
    _materiaCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    _tolCtrl.dispose();
    _diaCtrl.dispose();
    _aulaCtrl.dispose();
    _grupoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDocentes() async {
    try {
      final docentes = await _api.getDocentes();
      if (!mounted) return;
      setState(() {
        _docentes = docentes;
        _selectedDocente = docentes.isNotEmpty ? docentes.first : null;
        _isLoadingDocentes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDocentes = false;
        _errorMessage = 'No se pudieron cargar los docentes.';
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Campos incompletos. Complete los campos requeridos.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

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

    if (end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Horario inválido: la Hora de Fin debe ser mayor que la Hora de Inicio.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    if (_selectedDocente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecciona un docente para asignar el horario.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    if (_grupoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Captura el grupo para aplicar el horario a todos los alumnos.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    final mapa = {
      'docenteId': _selectedDocente!.id,
      'docenteNombre': _selectedDocente!.name,
      'grupo': _grupoCtrl.text.trim(),
      'materia': _materiaCtrl.text.trim(),
      'inicio': _inicioCtrl.text.trim(),
      'fin': _finCtrl.text.trim(),
      'tolerancia': _tolCtrl.text.trim().isEmpty ? '0' : _tolCtrl.text.trim(),
      'dia': _diaCtrl.text.trim().isEmpty ? 'Sin día' : _diaCtrl.text.trim(),
      'aula': _aulaCtrl.text.trim().isEmpty ? 'Sin aula' : _aulaCtrl.text.trim(),
    };

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _api.addSchedule(
        ownerId: _selectedDocente!.id,
        ownerRole: 'docente',
        materia: mapa['materia']!,
        inicio: mapa['inicio']!,
        fin: mapa['fin']!,
        dia: mapa['dia'],
        aula: mapa['aula'],
        grupo: mapa['grupo'],
        toleranciaMin: mapa['tolerancia'],
      );

      if (!mounted) return;
      setState(() {
        _horarios.add(mapa);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Horario guardado y aplicado al grupo.'),
          backgroundColor: Colors.green,
        ),
      );

      _materiaCtrl.clear();
      _inicioCtrl.clear();
      _finCtrl.clear();
      _tolCtrl.clear();
      _diaCtrl.clear();
      _aulaCtrl.clear();
      _grupoCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo guardar el horario. Intenta de nuevo.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar horario: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
      appBar: AppBar(title: const Text('Gestión de Horarios')),
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
                    'Nuevo horario docente',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDocenteDropdown(),
                  const SizedBox(height: 10),
                  _buildField(_materiaCtrl, 'Materia'),
                  const SizedBox(height: 10),
                  _buildField(_grupoCtrl, 'Grupo (se aplicará a todos los alumnos)'),
                  const SizedBox(height: 10),
                  _buildField(_inicioCtrl, 'Hora de Inicio (HH:MM)'),
                  const SizedBox(height: 10),
                  _buildField(_finCtrl, 'Hora de Fin (HH:MM)'),
                  const SizedBox(height: 10),
                  _buildField(_diaCtrl, 'Día'),
                  const SizedBox(height: 10),
                  _buildField(_aulaCtrl, 'Aula / Salón'),
                  const SizedBox(height: 10),
                  _buildField(_tolCtrl, 'Minutos de Tolerancia'),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepBlue,
                        foregroundColor: AppColors.onDeepBlue,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Guardar horario para el grupo'),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Horarios registrados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: 10),
            if (_isLoadingDocentes)
              const Center(child: CircularProgressIndicator())
            else if (_docentes.isEmpty)
              const Center(child: Text('No se encontraron docentes para asignar horarios.'))
            else if (_horarios.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No hay horarios creados aún. Agrega uno para comenzar.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ..._horarios.map((hora) {
                return Column(
                  children: [
                    _buildSubjectTile(
                      title: hora['materia'] ?? 'Materia',
                      subtitle:
                          '${hora['docenteNombre']} · Grupo ${hora['grupo']} · ${hora['dia']} · ${hora['inicio']} - ${hora['fin']} · Aula: ${hora['aula']} · Tolerancia: ${hora['tolerancia']} min',
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDocenteDropdown() {
    if (_isLoadingDocentes) {
      return const Center(child: CircularProgressIndicator());
    }

    return DropdownButtonFormField<UserModel>(
      value: _selectedDocente,
      decoration: InputDecoration(
        labelText: 'Docente',
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _docentes
          .map((docente) => DropdownMenuItem(
                value: docente,
                child: Text(docente.name),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedDocente = value;
        });
      },
      validator: (value) {
        if (value == null) return 'Selecciona un docente';
        return null;
      },
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
