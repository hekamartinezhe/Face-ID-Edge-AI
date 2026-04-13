import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'admin/admin_dashboard_screen.dart';
import 'camera_screen.dart';
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
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  static const int _requiredBypassTaps = 3;
  static const Duration _bypassTapWindow = Duration(seconds: 2);
  int _bypassTapCount = 0;
  DateTime? _lastBypassTapAt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
          child: Column(
            children: [
              GestureDetector(
                onTap: _handleBypassTap,
                child: const Icon(Icons.verified_user_rounded, size: 90, color: AppColors.deepBlue),
              ),
              const SizedBox(height: 24),
              const Text('Face-ID Edge AI', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.deepBlue)),
              const SizedBox(height: 10),
              const Text(
                'Ingresa con tu correo institucional o con tu rostro para acceder al sistema.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(labelText: 'Correo institucional', prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLoginButtonTap,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('INICIAR SESIÓN'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.face_rounded),
                  label: const Text('Ingresar con rostro'),
                  onPressed: _loginWithFace,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loginWithCredentials() async {
    final email = _userController.text.trim();
    final password = _passController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Ingresa correo institucional y contraseña');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.login(email, password);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, DashboardScreen.routeName);
    } catch (e) {
      _showMessage('Error de inicio de sesión: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleLoginButtonTap() {
    final email = _userController.text.trim();
    final password = _passController.text.trim();
    final bool isEmptyCredentials = email.isEmpty && password.isEmpty;

    if (isEmptyCredentials) {
      _registerBypassTap();
      return;
    }

    _resetBypassTapCounter();
    _loginWithCredentials();
  }

  void _handleBypassTap() {
    _registerBypassTap();
  }

  void _registerBypassTap() {
    final now = DateTime.now();
    if (_lastBypassTapAt == null || now.difference(_lastBypassTapAt!) > _bypassTapWindow) {
      _bypassTapCount = 0;
    }

    _lastBypassTapAt = now;
    _bypassTapCount += 1;

    if (_bypassTapCount >= _requiredBypassTaps) {
      _resetBypassTapCounter();
      _openAdminBypass();
    }
  }

  void _resetBypassTapCounter() {
    _bypassTapCount = 0;
    _lastBypassTapAt = null;
  }

  void _openAdminBypass() {
    if (!mounted) return;
    final bypassUser = UserModel(
      id: 'bypass-admin',
      name: 'Administrador Demo',
      email: 'admin.demo@local',
      role: UserRole.admin,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDashboardScreen(user: bypassUser),
      ),
    );
  }

  void _loginWithFace() {
    Navigator.pushNamed(context, CameraScreen.routeName, arguments: {'mode': 'login-face'});
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
