enum UserRole { alumno, docente, admin }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String matricula;
  final UserRole role;
  final String? token; // Token JWT para autorizar peticiones (RF-04)
  final List<double>? vector; // Embedding facial opcional
  final String? fotoUrl; // URL de la foto de perfil
  final String? carrera;
  final String? grupo;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.matricula = '',
    required this.role,
    this.token,
    this.vector,
    this.fotoUrl,
    this.carrera,
    this.grupo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<double>? vec;
    if (json['vector'] != null) {
      vec = (json['vector'] as List).map((e) => (e as num).toDouble()).toList();
    }

    UserRole parseRole(String? roleStr) {
      switch (roleStr?.toLowerCase()) {
        case 'docente':
        case 'teacher':
          return UserRole.docente;
        case 'admin':
        case 'administrador':
          return UserRole.admin;
        case 'alumno':
        case 'student':
        default:
          return UserRole.alumno;
      }
    }

    return UserModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name'] ?? json['nombre'] ?? '',
      email: json['email'] ?? json['correo'] ?? '',
      matricula: json['matricula'] ?? json['student_id'] ?? '',
      role: parseRole(json['role'] ?? json['rol']),
      token: json['token'] ?? json['access_token'],
      vector: vec,
      fotoUrl: json['foto_url'] ?? json['fotoUrl'] ?? json['photo_url'],
      carrera: json['carrera'] ?? json['career'],
      grupo: json['grupo'] ?? json['group'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'matricula': matricula,
        'role': role == UserRole.docente
            ? 'docente'
            : role == UserRole.admin
                ? 'admin'
                : 'alumno',
        'token': token,
        'vector': vector,
        'foto_url': fotoUrl,
        'carrera': carrera,
        'grupo': grupo,
      };

  bool get isAdmin => role == UserRole.admin;
  bool get isDocente => role == UserRole.docente;
  bool get isAlumno => role == UserRole.alumno;

  String get roleDisplayName {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.docente:
        return 'Docente';
      case UserRole.alumno:
        return 'Alumno';
    }
  }
}

