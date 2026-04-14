import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class DocenteScheduleScreen extends StatefulWidget {
  final UserModel docente;

  const DocenteScheduleScreen({super.key, required this.docente});

  @override
  State<DocenteScheduleScreen> createState() => _DocenteScheduleScreenState();
}

class _DocenteScheduleScreenState extends State<DocenteScheduleScreen> {
  final ApiService _api = ApiService();
  late Future<List<Map<String, dynamic>>> _clasesFuture;

  @override
  void initState() {
    super.initState();
    _clasesFuture = _api.getClasesDocente(docenteId: widget.docente.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horario completo del docente'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _clasesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar horario: ${snapshot.error}'));
          }

          final clases = List<Map<String, dynamic>>.from(snapshot.data ?? []);
          _sortClases(clases);
          if (clases.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Aún no hay clases registradas para este docente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: clases.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final clase = clases[index];
              final materia = clase['materia']?.toString() ?? 'Sin materia';
              final inicio = clase['inicio']?.toString() ?? '--:--';
              final fin = clase['fin']?.toString() ?? '--:--';
              final aula = clase['aula']?.toString() ?? 'No asignada';
              final grupo = clase['grupo']?.toString() ?? 'No asignado';
              final dia = clase['dia']?.toString() ?? 'Sin día';
              final tolerancia = clase['tolerancia_min']?.toString() ?? '0';

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      materia,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildInfoChip(Icons.calendar_today, dia),
                        const SizedBox(width: 8),
                        _buildInfoChip(Icons.schedule, '$inicio - $fin'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildInfoChip(Icons.location_on, aula),
                        const SizedBox(width: 8),
                        _buildInfoChip(Icons.group, grupo),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tolerancia: $tolerancia min',
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _sortClases(List<Map<String, dynamic>> clases) {
    const dayOrder = {
      'lunes': 1,
      'martes': 2,
      'miércoles': 3,
      'miercoles': 3,
      'jueves': 4,
      'viernes': 5,
      'sábado': 6,
      'sabado': 6,
      'domingo': 7,
    };

    int dayIndex(String value) {
      return dayOrder[value.toLowerCase().trim()] ?? 99;
    }

    int minuteValue(String time) {
      final parts = time.split(':');
      if (parts.length != 2) return 0;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return h * 60 + m;
    }

    clases.sort((a, b) {
      final diaA = a['dia']?.toString() ?? '';
      final diaB = b['dia']?.toString() ?? '';
      final aIndex = dayIndex(diaA);
      final bIndex = dayIndex(diaB);
      if (aIndex != bIndex) return aIndex.compareTo(bIndex);
      final inicioA = minuteValue(a['inicio']?.toString() ?? '00:00');
      final inicioB = minuteValue(b['inicio']?.toString() ?? '00:00');
      return inicioA.compareTo(inicioB);
    });
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.deepBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
