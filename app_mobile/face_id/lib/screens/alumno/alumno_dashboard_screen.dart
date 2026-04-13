// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'tomar_asistencia_screen.dart';

/// Vista principal del Alumno - Figura 20, 21, 22, 23
/// Muestra el horario del alumno y permite tomar asistencia con reconocimiento facial
class AlumnoDashboardScreen extends StatefulWidget {
  final UserModel user;

  const AlumnoDashboardScreen({super.key, required this.user});

  @override
  State<AlumnoDashboardScreen> createState() => _AlumnoDashboardScreenState();
}

class _AlumnoDashboardScreenState extends State<AlumnoDashboardScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _clasesHoy = [];

  @override
  void initState() {
    super.initState();
    _loadHorario();
  }

  Future<void> _loadHorario() async {
    try {
      final horario = await _api.getHorario(widget.user.id);
      setState(() {
        _clasesHoy = horario.map((item) {
          return {
            'id': item['id'] ?? item['clase_id'] ?? item['materia'] ?? 'clase-unknown',
            'materia': item['materia'] ?? item['nombre'] ?? 'Clase',
            'docente': item['docente'] ?? item['teacher'] ?? 'Docente',
            'horaInicio': item['hora_inicio'] ?? item['horaInicio'] ?? '08:00',
            'horaFin': item['hora_fin'] ?? item['horaFin'] ?? '10:00',
            'aula': item['aula'] ?? item['salon'] ?? 'Aula',
            'estado': item['estado'] ?? 'pendiente',
          };
        }).toList();
      });
    } catch (_) {
      setState(() {
        _clasesHoy = [
          {
            'materia': 'Inteligencia Artificial',
            'docente': 'Dra. Lizbeth Ibarra',
            'horaInicio': '08:00',
            'horaFin': '10:00',
            'aula': 'Lab-CMD-01',
            'estado': 'pendiente',
            'id': 'ia-01',
          },
          {
            'materia': 'Desarrollo Móvil',
            'docente': 'Ing. Carlos Ortiz',
            'horaInicio': '10:30',
            'horaFin': '12:30',
            'aula': 'Lab-CMD-02',
            'estado': 'pendiente',
            'id': 'dm-02',
          },
        ];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3799),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FACE ID',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Hola, ${widget.user.name}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _auth.logout();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3799),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mi Horario de Hoy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getFormattedDate(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _clasesHoy.isEmpty ? null : () => _navigateToAttendance(),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Registrar asistencia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3799),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _clasesHoy.isEmpty
                    ? const Center(child: Text('No hay clases programadas hoy.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _clasesHoy.length,
                        itemBuilder: (context, index) {
                          final clase = _clasesHoy[index];
                          return _buildClaseCard(clase);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _navigateToAttendance() {
    final pending = _clasesHoy.firstWhere(
      (clase) => clase['estado'] == 'pendiente',
      orElse: () => _clasesHoy.first,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TomarAsistenciaScreen(
          user: widget.user,
          clase: pending,
        ),
      ),
    );
  }

  Widget _buildClaseCard(Map<String, dynamic> clase) {
    final Color estadoColor = _getEstadoColor(clase['estado'] as String);
    final IconData estadoIcon = _getEstadoIcon(clase['estado'] as String);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    clase['materia'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: estadoColor.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: estadoColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estadoIcon, size: 16, color: estadoColor),
                      const SizedBox(width: 4),
                      Text(
                        (clase['estado'] as String).toUpperCase(),
                        style: TextStyle(
                          color: estadoColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, '${clase['horaInicio']} - ${clase['horaFin']}'),
            _buildInfoRow(Icons.person, clase['docente'] as String),
            _buildInfoRow(Icons.location_on, clase['aula'] as String),
            const SizedBox(height: 16),
            if (clase['estado'] == 'pendiente')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TomarAsistenciaScreen(user: widget.user, clase: clase),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('TOMAR ASISTENCIA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3799),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (clase['estado'] == 'asistido')
              SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'ASISTENCIA REGISTRADA',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'asistido':
      case 'puntual':
        return Colors.green;
      case 'retardo':
        return Colors.orange;
      case 'falta':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'puntual':
      case 'asistido':
        return Icons.check_circle;
      case 'retardo':
        return Icons.watch_later;
      case 'falta':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }
}
