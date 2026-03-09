enum UserRole { alumno, docente }

class UserModel {
  final String id;
  final String name;
  final UserRole role;
  final String? token; // Token JWT para autorizar peticiones (RF-04)

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.token,
  });
}
