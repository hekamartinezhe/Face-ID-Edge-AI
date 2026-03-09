import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  final AuthService _auth = AuthService();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Face-ID: Selección de Rol")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Acceso al Sistema de Asistencia", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _login(context, UserRole.alumno),
              child: const Text("INGRESAR COMO ALUMNO"),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: () => _login(context, UserRole.docente),
              child: const Text("INGRESAR COMO DOCENTE", 
                style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _login(BuildContext context, UserRole role) async {
    // Generamos un usuario de prueba para validar la persistencia (RF-04)
    final user = UserModel(
      id: "u_test_01", 
      name: "Héctor Kaleb", 
      role: role
    );
    
    await _auth.saveUserSession(user);
    print("Vibe Check: Sesión de ${role.name} guardada localmente.");
    
    // El siguiente movimiento será la navegación a la cámara para el Split Computing
  }
}
