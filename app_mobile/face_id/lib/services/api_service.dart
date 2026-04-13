import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

/// Servicio centralizado para todas las llamadas a la API
/// Reemplaza el acceso directo a MongoDB
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // URL pública de ngrok para compilar y conectar con el backend.
  static const String baseUrl = 'https://59d9-177-229-178-140.ngrok-free.app';
  // static const String baseUrl = 'http://192.168.1.100:8000'; // Desarrollo local
  
  String? _authToken;
  
  void setToken(String token) {
    _authToken = token;
  }
  
  void clearToken() {
    _authToken = null;
  }
  
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  // ==================== AUTENTICACIÓN ====================
  
  /// Login con email y contraseña
  Future<UserModel> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setToken(data['token']);
      return UserModel.fromJson(data['user']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error de autenticación');
    }
  }

  /// Login con reconocimiento facial (para alumnos registrados)
  Future<UserModel> loginWithFace(Uint8List faceImage) async {
    final base64Image = base64Encode(faceImage);
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login-face'),
      headers: _headers,
      body: jsonEncode({'image': base64Image}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setToken(data['token']);
      return UserModel.fromJson(data['user']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Rostro no reconocido');
    }
  }

  /// Verificar si hay una sesión activa
  Future<UserModel?> checkSession() async {
    if (_authToken == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== ADMIN: GESTIÓN DE USUARIOS ====================
  
  /// Registrar nuevo alumno (con captura facial)
  Future<UserModel> registerAlumno({
    required String name,
    required String email,
    required String matricula,
    required String password,
    required Uint8List faceImage,
    String? carrera,
    String? grupo,
  }) async {
    final base64Image = base64Encode(faceImage);
    
    final response = await http.post(
      Uri.parse('$baseUrl/admin/alumnos'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'matricula': matricula,
        'password': password,
        'face_image': base64Image,
        'carrera': carrera,
        'grupo': grupo,
        'role': 'alumno',
      }),
    );

    if (response.statusCode == 201) {
      return UserModel.fromJson(jsonDecode(response.body));
    }

    try {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al registrar alumno');
    } catch (e) {
      throw Exception('Error al registrar alumno: ${response.body}');
    }
  }

  /// Registrar nuevo docente
  Future<UserModel> registerDocente({
    required String name,
    required String email,
    required String password,
    String? especialidad,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/docentes'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'especialidad': especialidad,
        'role': 'docente',
      }),
    );

    if (response.statusCode == 201) {
      return UserModel.fromJson(jsonDecode(response.body));
    }

    try {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al registrar docente');
    } catch (e) {
      throw Exception('Error al registrar docente: ${response.body}');
    }
  }

  /// Actualizar usuario existente (alumno o docente)
  Future<UserModel> updateUser({
    required String id,
    required String name,
    required String email,
    required UserRole role,
    String? password,
    String? matricula,
    String? especialidad,
    String? carrera,
    String? grupo,
  }) async {
    final endpoint = role == UserRole.docente ? 'admin/docentes' : 'admin/alumnos';
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
      body: jsonEncode({
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'matricula': matricula,
        'especialidad': especialidad,
        'carrera': carrera,
        'grupo': grupo,
        'role': role == UserRole.docente ? 'docente' : 'alumno',
      }),
    );

    if (response.statusCode == 201) {
      return UserModel.fromJson(jsonDecode(response.body));
    }

    try {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al actualizar usuario');
    } catch (e) {
      throw Exception('Error al actualizar usuario: ${response.body}');
    }
  }

  /// Agregar un horario/clase para un alumno o docente
  Future<Map<String, dynamic>> addSchedule({
    required String ownerId,
    required String ownerRole,
    required String materia,
    required String inicio,
    required String fin,
    String? toleranciaMin,
    String? dia,
    String? aula,
    String? grupo,
    String? claseId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/horarios'),
      headers: _headers,
      body: jsonEncode({
        'owner_id': ownerId,
        'owner_role': ownerRole,
        'materia': materia,
        'inicio': inicio,
        'fin': fin,
        'tolerancia_min': int.tryParse(toleranciaMin ?? '0') ?? 0,
        'dia': dia,
        'aula': aula,
        'grupo': grupo,
        'clase_id': claseId,
      }),
    );

    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    try {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al agregar horario');
    } catch (e) {
      throw Exception('Error al agregar horario: ${response.body}');
    }
  }

  /// Obtener lista de alumnos
  Future<List<UserModel>> getAlumnos({String? search, String? grupo}) async {
    final queryParams = <String, String>{};
    if (search != null) queryParams['search'] = search;
    if (grupo != null) queryParams['grupo'] = grupo;
    
    final uri = Uri.parse('$baseUrl/admin/alumnos')
        .replace(queryParameters: queryParams);
    
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => UserModel.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener alumnos');
    }
  }

  /// Obtener lista de docentes
  Future<List<UserModel>> getDocentes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/docentes'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => UserModel.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener docentes');
    }
  }

  // ==================== ALUMNO: HORARIO Y ASISTENCIA ====================
  
  /// Obtener horario del alumno
  Future<List<Map<String, dynamic>>> getHorario(String alumnoId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/alumnos/$alumnoId/horario'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener horario');
    }
  }

  /// Registrar asistencia con reconocimiento facial
  Future<Map<String, dynamic>> registrarAsistencia({
    required String alumnoId,
    required String claseId,
    required Uint8List faceImage,
  }) async {
    final base64Image = base64Encode(faceImage);
    
    final response = await http.post(
      Uri.parse('$baseUrl/asistencias'),
      headers: _headers,
      body: jsonEncode({
        'alumno_id': alumnoId,
        'clase_id': claseId,
        'face_image': base64Image,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al registrar asistencia');
    }
  }

  /// Obtener historial de asistencias del alumno
  Future<List<Map<String, dynamic>>> getAsistenciasAlumno(String alumnoId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/alumnos/$alumnoId/asistencias'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener asistencias');
    }
  }

  // ==================== DOCENTE: ASISTENCIAS ====================
  
  /// Obtener asistencias de las clases del docente
  Future<List<Map<String, dynamic>>> getAsistenciasDocente({
    String? fecha,
    String? claseId,
  }) async {
    final queryParams = <String, String>{};
    if (fecha != null) queryParams['fecha'] = fecha;
    if (claseId != null) queryParams['clase_id'] = claseId;
    
    final uri = Uri.parse('$baseUrl/docente/asistencias')
        .replace(queryParameters: queryParams);
    
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener asistencias');
    }
  }

  /// Obtener clases del docente
  Future<List<Map<String, dynamic>>> getClasesDocente({String? docenteId}) async {
    final queryParams = <String, String>{};
    if (docenteId != null) queryParams['docente_id'] = docenteId;

    final uri = Uri.parse('$baseUrl/docente/clases')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener clases');
    }
  }

  // ==================== GENERAL ====================
  
  /// Verificar conexión con el servidor
  Future<bool> healthCheck() async {
    try {
        final response = await http
          .get(Uri.parse('$baseUrl/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}