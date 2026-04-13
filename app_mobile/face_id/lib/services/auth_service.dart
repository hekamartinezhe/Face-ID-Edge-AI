import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _api = ApiService();
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Iniciar sesión con email y contraseña
  Future<UserModel> login(String email, String password) async {
    final user = await _api.login(email, password);
    _currentUser = user;
    await saveUserSession(user);
    return user;
  }

  /// Iniciar sesión con reconocimiento facial
  Future<UserModel> loginWithFace(List<int> faceImageBytes) async {
    final user = await _api.loginWithFace(Uint8List.fromList(faceImageBytes));
    _currentUser = user;
    await saveUserSession(user);
    return user;
  }

  /// Verificar si hay sesión guardada
  Future<UserModel?> checkSavedSession() async {
    final user = await _api.checkSession();
    if (user != null) {
      _currentUser = user;
    }
    return user;
  }

  /// Guardar sesión en almacenamiento local
  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_role', user.role.name);
    if (user.token != null) {
      await prefs.setString('auth_token', user.token!);
      _api.setToken(user.token!);
    }
  }

  /// Recuperar rol guardado
  Future<UserRole?> getStoredRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString('user_role');
    if (roleStr == 'admin') return UserRole.admin;
    if (roleStr == 'docente') return UserRole.docente;
    if (roleStr == 'alumno') return UserRole.alumno;
    return null;
  }

  /// Recuperar token guardado
  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Inicializar sesión desde storage
  Future<void> initializeFromStorage() async {
    final token = await getStoredToken();
    if (token != null) {
      _api.setToken(token);
      await checkSavedSession();
    }
  }

  /// Cerrar sesión
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _api.clearToken();
    _currentUser = null;
  }
}

