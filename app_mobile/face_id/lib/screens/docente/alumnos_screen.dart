import 'package:flutter/material.dart';

/// Lista de Alumnos - Figura 26
/// Visualización de alumnos registrados en el sistema
class AlumnosScreen extends StatefulWidget {
  const AlumnosScreen({super.key});

  @override
  State<AlumnosScreen> createState() => _AlumnosScreenState();
}

class _AlumnosScreenState extends State<AlumnosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'todos'; // todos, activos, inactivos

  // Datos de ejemplo - en producción vendrían del backend
  final List<Map<String, dynamic>> _alumnos = [
    {
      'matricula': 'TIC-320091',
      'nombre': 'Julissa Guadalupe Gutierrez Velazquez',
      'carrera': 'TICs',
      'grupo': '8° A',
      'estado': 'activo',
      'registrado': true,
      'foto': null,
    },
    {
      'matricula': 'TIC-320080',
      'nombre': 'Johan Fernando Sierra Lopez',
      'carrera': 'TICs',
      'grupo': '8° A',
      'estado': 'activo',
      'registrado': true,
      'foto': null,
    },
    {
      'matricula': 'TIC-320029',
      'nombre': 'Fernando de Jesus Arce Armenta',
      'carrera': 'TICs',
      'grupo': '8° A',
      'estado': 'activo',
      'registrado': true,
      'foto': null,
    },
    {
      'matricula': 'TIC-320042',
      'nombre': 'Hector Kaleb Martinez Hernandez',
      'carrera': 'TICs',
      'grupo': '8° A',
      'estado': 'activo',
      'registrado': false,
      'foto': null,
    },
    {
      'matricula': 'TIC-320015',
      'nombre': 'María Fernanda López García',
      'carrera': 'TICs',
      'grupo': '8° B',
      'estado': 'activo',
      'registrado': true,
      'foto': null,
    },
  ];

  List<Map<String, dynamic>> get _filteredAlumnos {
    return _alumnos.where((alumno) {
      final matchesSearch = alumno['nombre']
          .toString()
          .toLowerCase()
          .contains(_searchController.text.toLowerCase()) ||
          alumno['matricula']
              .toString()
              .toLowerCase()
              .contains(_searchController.text.toLowerCase());
      
      if (_filter == 'todos') return matchesSearch;
      if (_filter == 'registrados') return matchesSearch && alumno['registrado'];
      if (_filter == 'pendientes') return matchesSearch && !alumno['registrado'];
      return matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // Header con búsqueda
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
                // Barra de búsqueda
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.search, color: Colors.white70),
                      hintText: 'Buscar alumno...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Filtros
                Row(
                  children: [
                    _buildFilterChip('Todos', 'todos'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Registrados', 'registrados'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pendientes', 'pendientes'),
                  ],
                ),
              ],
            ),
          ),
          
          // Contador
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredAlumnos.length} alumnos',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  '${_alumnos.where((a) => a['registrado']).length} registrados',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de alumnos
          Expanded(
            child: _filteredAlumnos.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron alumnos',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredAlumnos.length,
                    itemBuilder: (context, index) {
                      final alumno = _filteredAlumnos[index];
                      return _buildAlumnoCard(alumno);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1E3799) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAlumnoCard(Map<String, dynamic> alumno) {
    final isRegistrado = alumno['registrado'] as bool;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isRegistrado
                      ? [const Color(0xFF00B894), const Color(0xFF00CEC9)]
                      : [Colors.grey.shade400, Colors.grey.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(
                child: Text(
                  alumno['nombre'].toString().split(' ').map((n) => n[0]).take(2).join(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alumno['nombre'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${alumno['matricula']} · ${alumno['carrera']} · ${alumno['grupo']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRegistrado
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRegistrado ? Icons.verified : Icons.pending,
                          size: 12,
                          color: isRegistrado ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isRegistrado ? 'Registrado' : 'Pendiente',
                          style: TextStyle(
                            fontSize: 11,
                            color: isRegistrado ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Menú
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) {
                if (value == 'ver') _verDetalleAlumno(alumno);
                if (value == 'editar') _editarAlumno(alumno);
                if (value == 'eliminar') _eliminarAlumno(alumno);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'ver', child: Text('Ver detalles')),
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _verDetalleAlumno(Map<String, dynamic> alumno) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3799), Color(0xFF4A69BD)],
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Center(
                  child: Text(
                    alumno['nombre'].toString().split(' ').map((n) => n[0]).take(2).join(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                alumno['nombre'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                alumno['matricula'],
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              _buildInfoRow('Carrera', alumno['carrera']),
              _buildInfoRow('Grupo', alumno['grupo']),
              _buildInfoRow('Estado', alumno['estado']),
              _buildInfoRow(
                'Registro Facial',
                alumno['registrado'] ? 'Completado' : 'Pendiente',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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

  void _editarAlumno(Map<String, dynamic> alumno) {
    // TODO: Implementar edición
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Editar alumno - Próximamente')),
    );
  }

  void _eliminarAlumno(Map<String, dynamic> alumno) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar a ${alumno['nombre']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _alumnos.remove(alumno));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alumno eliminado')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}