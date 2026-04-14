import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../models/user_model.dart';
import '../../screens/edit_user_screen.dart';
import '../../screens/docente/docente_schedule_screen.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../enrollment_screen.dart';
import '../login_screen.dart';
import 'add_docente_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserModel user;
  const AdminDashboardScreen({super.key, required this.user});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  late Future<List<UserModel>> _docentesFuture;
  late Future<List<UserModel>> _alumnosFuture;

  @override
  void initState() {
    super.initState();
    _docentesFuture = _api.getDocentes();
    _alumnosFuture = _api.getAlumnos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Administrador · ${widget.user.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _auth.logout();
              if (!mounted) return;
              navigator.pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Panel de Administración',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Gestiona docentes y alumnos registrados desde el servidor.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Agregar docente'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddDocenteScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Registrar alumno'),
                      onPressed: () => Navigator.pushNamed(context, EnrollmentScreen.routeName),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const TabBar(
                labelColor: AppColors.deepBlue,
                unselectedLabelColor: Colors.black54,
                indicatorColor: AppColors.deepBlue,
                tabs: [
                  Tab(icon: Icon(Icons.school), text: 'Docentes'),
                  Tab(icon: Icon(Icons.person), text: 'Alumnos'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildDocentesTab(),
                    _buildAlumnosTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocentesTab() {
    return FutureBuilder<List<UserModel>>(
      future: _docentesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar docentes: ${snapshot.error}'));
        }
        final docentes = snapshot.data ?? [];
        if (docentes.isEmpty) {
          return const Center(child: Text('No hay docentes registrados aún.'));
        }
        return ListView.separated(
          itemCount: docentes.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final docente = docentes[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.deepBlue,
                child: Text(docente.name.isNotEmpty ? docente.name[0] : 'D'),
              ),
              title: Text(docente.name),
              subtitle: Text(docente.email),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.schedule, color: AppColors.deepBlue),
                    tooltip: 'Ver horario',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DocenteScheduleScreen(docente: docente),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.deepBlue),
                    tooltip: 'Editar docente',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditUserScreen(user: docente.toJson()),
                        ),
                      );
                    },
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocenteScheduleScreen(docente: docente),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAlumnosTab() {
    return FutureBuilder<List<UserModel>>(
      future: _alumnosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar alumnos: ${snapshot.error}'));
        }
        final alumnos = snapshot.data ?? [];
        if (alumnos.isEmpty) {
          return const Center(child: Text('No hay alumnos registrados aún.'));
        }
        return ListView.separated(
          itemCount: alumnos.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final alumno = alumnos[index];
            final grupoText = alumno.grupo?.isNotEmpty == true ? ' · Grupo ${alumno.grupo}' : '';
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.deepBlue,
                child: Text(alumno.name.isNotEmpty ? alumno.name[0] : 'A'),
              ),
              title: Text(alumno.name),
              subtitle: Text('${alumno.email}$grupoText'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: AppColors.deepBlue),
                tooltip: 'Editar alumno',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditUserScreen(user: alumno.toJson()),
                    ),
                  );
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditUserScreen(user: alumno.toJson()),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
