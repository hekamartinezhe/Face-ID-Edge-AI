import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
 // sesión del usuario 
  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_role', user.role.name);
    if (user.token != null) {
      await prefs.setString('auth_token', user.token!);
    }
  }

  // Recupera el rol guardado para el flujo de la app
  Future<UserRole?> getStoredRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString('user_role');
    if (roleStr == 'docente') return UserRole.docente;
    if (roleStr == 'alumno') return UserRole.alumno;
    return null;
  }

  // limpiar la sesión (Logout)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
