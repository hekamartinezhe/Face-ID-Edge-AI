import 'package:flutter/material.dart';

/// Control de Asistencias - Figura 27
/// Visualización de asistencias del día/semana
class AsistenciasScreen extends StatefulWidget {
  const AsistenciasScreen({super.key});

  @override
  State<AsistenciasScreen> createState() => _AsistenciasScreenState();
}

class _AsistenciasScreenState extends State<AsistenciasScreen> {
  String _selectedFecha = 'Hoy';
  String _selectedClase = 'Todas';
  
  // Datos de ejemplo
  final List<Map<String, dynamic>> _asistencias = [
    {
      'alumno': 'Julissa Guadalupe Gutierrez Velazquez',
      'matricula': 'TIC-320091',
      'hora': '08:02',
      'estado': 'puntual',
      'clase': 'Inteligencia Artificial',
      'metodo': 'facial',
    },
    {
      'alumno': 'Johan Fernando Sierra Lopez',
      'matricula': 'TIC-320080',
      'hora': '08:05',
      'estado': 'puntual',
      'clase': 'Inteligencia Artificial',
      'metodo': 'facial',
    },
    {
      'alumno': 'Fernando de Jesus Arce Armenta',
      'matricula': 'TIC-320029',
      'hora': '08:18',
      'estado': 'retardo',
      'clase': 'Inteligencia Artificial',
      'metodo': 'facial',
    },
    {
      'alumno': 'Hector Kaleb Martinez Hernandez',
      'matricula': 'TIC-320042',
      'hora': '--:--',
      'estado': 'falta',
      'clase': 'Inteligencia Artificial',
      'metodo': '--',
    },
    {
      'alumno': 'María Fernanda López García',
      'matricula': 'TIC-320015',
      'hora': '08:01',
      'estado': 'puntual',
      'clase': 'Desarrollo Móvil',
      'metodo': 'facial',
    },
  ];

  List<Map<String, dynamic>> get _filteredAsistencias {
    return _asistencias.where((a) {
      if (_selectedClase != 'Todas' && a['clase'] != _selectedClase) return false;
      return true;
    }).toList();
  }

  Map<String, int> get _resumen {
    final filtradas = _filteredAsistencias;
    return {
      'puntual': filtradas.where((a) => a['estado'] == 'puntual').length,
      'retardo': filtradas.where((a) => a['estado'] == 'retardo').length,
      'falta': filtradas.where((a) => a['estado'] == 'falta').length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _resumen;
    final total = _filteredAsistencias.length;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3799),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Filtros
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        value: _selectedFecha,
                        items: const ['Hoy', 'Ayer', 'Esta semana'],
                        onChanged: (v) => setState(() => _selectedFecha = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        value: _selectedClase,
                        items: const ['Todas', 'Inteligencia Artificial', 'Desarrollo Móvil'],
                        onChanged: (v) => setState(() => _selectedClase = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Resumen
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.05 * 255).toInt()),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResumenItem(
                  'Puntuales',
                  resumen['puntual']!,
                  total,
                  Colors.green,
                  Icons.check_circle,
                ),
                _buildResumenItem(
                  'Retardos',
                  resumen['retardo']!,
                  total,
                  Colors.orange,
                  Icons.watch_later,
                ),
                _buildResumenItem(
                  'Faltas',
                  resumen['falta']!,
                  total,
                  Colors.red,
                  Icons.cancel,
                ),
              ],
            ),
          ),
          
          // Lista
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredAsistencias.length,
              itemBuilder: (context, index) {
                final asistencia = _filteredAsistencias[index];
                return _buildAsistenciaCard(asistencia);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportarAsistencias,
        backgroundColor: const Color(0xFF1E3799),
        icon: const Icon(Icons.download),
        label: const Text('Exportar'),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E3799),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(color: Colors.white)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildResumenItem(String label, int count, int total, Color color, IconData icon) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha((0.1 * 255).toInt()),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildAsistenciaCard(Map<String, dynamic> asistencia) {
    final estadoColor = _getEstadoColor(asistencia['estado']);
    final estadoIcon = _getEstadoIcon(asistencia['estado']);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: estadoColor.withAlpha((0.1 * 255).toInt()),
            shape: BoxShape.circle,
          ),
          child: Icon(estadoIcon, color: estadoColor),
        ),
        title: Text(
          asistencia['alumno'],
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${asistencia['matricula']} · ${asistencia['clase']}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  asistencia['hora'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                if (asistencia['metodo'] == 'facial')
                  Icon(Icons.face, size: 12, color: Colors.grey.shade500),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: estadoColor.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            asistencia['estado'].toUpperCase(),
            style: TextStyle(
              color: estadoColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _verDetalleAsistencia(asistencia),
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'puntual': return Colors.green;
      case 'retardo': return Colors.orange;
      case 'falta': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'puntual': return Icons.check_circle;
      case 'retardo': return Icons.watch_later;
      case 'falta': return Icons.cancel;
      default: return Icons.help;
    }
  }

  void _verDetalleAsistencia(Map<String, dynamic> asistencia) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              asistencia['alumno'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Matrícula', asistencia['matricula']),
            _buildDetailRow('Clase', asistencia['clase']),
            _buildDetailRow('Hora de registro', asistencia['hora']),
            _buildDetailRow('Método', asistencia['metodo'] == 'facial' ? 'Reconocimiento Facial' : 'No aplica'),
            _buildDetailRow('Estado', asistencia['estado'].toUpperCase()),
            const SizedBox(height: 24),
            if (asistencia['estado'] == 'falta')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _justificarFalta(asistencia);
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('JUSTIFICAR FALTA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _justificarFalta(Map<String, dynamic> asistencia) {
    // TODO: Implementar justificación
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Justificar falta - Próximamente')),
    );
  }

  void _exportarAsistencias() {
    // TODO: Implementar exportación
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exportando asistencias...')),
    );
  }
}