import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'dashboard_screen.dart';

enum UserRole { alumno, docente }

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserRole _selectedRole = UserRole.alumno;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.verified_user_rounded,
                size: 90,
                color: AppColors.deepBlue,
              ),
              const SizedBox(height: 20),
              const Text(
                'Face-ID Edge AI',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Acceso al sistema para demostracion final',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Correo institucional',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contrasena',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Perfil de acceso',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    RadioListTile<UserRole>(
                      dense: true,
                      value: UserRole.alumno,
                      groupValue: _selectedRole,
                      activeColor: AppColors.deepBlue,
                      title: const Text('Alumno'),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedRole = value);
                      },
                    ),
                    RadioListTile<UserRole>(
                      dense: true,
                      value: UserRole.docente,
                      groupValue: _selectedRole,
                      activeColor: AppColors.deepBlue,
                      title: const Text('Docente'),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedRole = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBlue,
                  foregroundColor: AppColors.onDeepBlue,
                ),
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    DashboardScreen.routeName,
                    arguments: {
                      'isDocente': _selectedRole == UserRole.docente,
                    },
                  );
                },
                child: const Text('Iniciar sesion'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}