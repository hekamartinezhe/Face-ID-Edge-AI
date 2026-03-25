import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'tomar_asistencia_screen.dart';

/// Vista principal del Alumno - Figura 20, 21, 22, 23
/// Muestra el horario y permite tomar asistencia con reconocimiento facial
class AlumnoDashboardScreen extends StatefulWidget {
  final UserModel user;
  
  const AlumnoDashboardScreen({super.key, required this.user});

  @override
  State<AlumnoDashboardScreen> createState() => _AlumnoDashboardScreenState();
}

class _AlumnoDashboardScreenState extends State<AlumnoDashboardScreen> {
  final AuthService _auth = AuthService();
  
  // Simulación de datos del horario del alumno
  final List<Map<String, dynamic>> _clasesHoy = [
    {
      'materia': 'Inteligencia Artificial',
      'docente': 'Dra. Lizbeth Ibarra',
      'horaInicio': '08:00',
      'horaFin': '10:00',
      'aula': 'Lab-CMD-01',
      'estado': 'pendiente', // pendiente, asistido, retardo, falta
    },
    {
      'materia': 'Desarrollo Móvil',
      'docente': 'Ing. Carlos Ortiz',
      'horaInicio': '10:30',
      'horaFin': '12:30',
      'aula': 'Lab-CMD-02',
      'estado': 'pendiente',
    },
    {
      'materia': 'Base de Datos',
      'docente': 'Ing. Julissa Gutiérrez',
      'horaInicio': '13:00',
      'horaFin': '15:00',
      'aula': 'Aula-304',
      'estado': 'asistido',
    },
  ];

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
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con fecha
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
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Lista de clases
          Expanded(
            child: ListView.builder(
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

  Widget _buildClaseCard(Map<String, dynamic> clase) {
    final Color estadoColor = _getEstadoColor(clase['estado']);
    final IconData estadoIcon = _getEstadoIcon(clase['estado']);
    
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
                    clase['materia'],
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
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: estadoColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estadoIcon, size: 16, color: estadoColor),
                      const SizedBox(width: 4),
                      Text(
                        clase['estado'].toUpperCase(),
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
            _buildInfoRow(Icons.person, clase['docente']),
            _buildInfoRow(Icons.location_on, clase['aula']),
            const SizedBox(height: 16),
            
            // Botón de asistencia
            if (clase['estado'] == 'pendiente')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _tomarAsistencia(clase),
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
              )
            else if (clase['estado'] == 'asistido')
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
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'asistido':
        return Colors.green;
      case 'retardo':
        return Colors.orange;
      case 'falta':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'asistido':
        return Icons.check_circle;
      case 'retardo':
        return Icons.warning;
      case 'falta':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 
                   'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    
    return '${dias[now.weekday - 1]}, ${now.day} de ${meses[now.month - 1]} de ${now.year}';
  }

  void _tomarAsistencia(Map<String, dynamic> clase) {
    // Verificar si está dentro del horario permitido
    final now = DateTime.now();
    final horaInicio = _parseHora(clase['horaInicio']);
    final horaFin = _parseHora(clase['horaFin']);
    
    // Ventana de 30 min antes de inicio hasta fin de clase
    final ventanaInicio = horaInicio.subtract(const Duration(minutes: 30));
    
    if (now.isBefore(ventanaInicio)) {
      // Fuera de horario - Figura 23
      _showResultadoDialog(
        title: 'Fuera de Horario',
        message: 'Aún no es hora de clase.\nLa clase comienza a las ${clase['horaInicio']}.',
        icon: Icons.access_time_filled,
        color: Colors.orange,
      );
      return;
    }
    
    if (now.isAfter(horaFin)) {
      // Fuera de horario - Figura 23
      _showResultadoDialog(
        title: 'Clase Terminada',
        message: 'La clase ya ha finalizado.\nNo se puede registrar asistencia.',
        icon: Icons.event_busy,
        color: Colors.red,
      );
      return;
    }
    
    // Navegar a pantalla de reconocimiento facial
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TomarAsistenciaScreen(
          user: widget.user,
          clase: clase,
        ),
      ),
    );
  }

  DateTime _parseHora(String horaStr) {
    final now = DateTime.now();
    final parts = horaStr.split(':');
    return DateTime(now.year, now.month, now.day, 
                    int.parse(parts[0]), int.parse(parts[1]));
  }

  void _showResultadoDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      ),
    );
  }
}