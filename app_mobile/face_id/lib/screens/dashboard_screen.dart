import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'admin/admin_dashboard_screen.dart';
import 'alumno/alumno_dashboard_screen.dart';
import 'docente/docente_dashboard_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  static const String routeName = '/dashboard';
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _auth = AuthService();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final currentUser = _auth.currentUser ?? await _auth.checkSavedSession();
    if (currentUser == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      return;
    }
    setState(() {
      _user = currentUser;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text('Usuario no identificado. Inicia sesión nuevamente.')),
      );
    }

    switch (_user!.role) {
      case UserRole.admin:
        return AdminDashboardScreen(user: _user!);
      case UserRole.docente:
        return DocenteDashboardScreen(user: _user!);
      case UserRole.alumno:
        return AlumnoDashboardScreen(user: _user!);
    }
  }
}

