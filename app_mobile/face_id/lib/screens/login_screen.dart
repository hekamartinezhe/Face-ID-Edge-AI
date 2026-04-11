import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/load_orchestrator_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  int _diagnosticTaps = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
          child: Column(
            children: [
              // Easter Egg en el Escudo
              GestureDetector(
                onTap: () {
                  _diagnosticTaps++;
                  if (_diagnosticTaps == 5) {
                    LoadOrchestratorService.instance.isDiagnosticModeEnabled = true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Modo de diagnóstico activado'), duration: Duration(seconds: 1)),
                    );
                  }
                },
                child: const Icon(Icons.verified_user_rounded, size: 90, color: AppColors.deepBlue),
              ),
              const SizedBox(height: 24),
              const Text('Face-ID Edge AI', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.deepBlue)),
              const SizedBox(height: 10),
              const Text('Identificación Biométrica de Próxima Generación', 
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 50),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(labelText: 'Usuario / Matrícula', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  final user = _userController.text.trim();
                  final pass = _passController.text.trim();
                  if (user.isEmpty) return;

                  // Login Inteligente: Docente si admin/1234, Alumno en cualquier otro caso
                  bool isDocente = (user == 'admin' && pass == '1234');
                  
                  Navigator.pushReplacementNamed(
                    context, 
                    DashboardScreen.routeName, 
                    arguments: { 'isDocente': isDocente }
                  );
                },
                child: const Text('INICIAR SESIÓN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
