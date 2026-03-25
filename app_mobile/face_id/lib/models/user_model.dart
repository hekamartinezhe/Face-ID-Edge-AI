enum UserRole { alumno, docente }

class UserModel {
  final String id;
  final String name;
  final UserRole role;
  final String? token; // Token JWT para autorizar peticiones (RF-04)
  final List<double>? vector; // Embedding facial opcional

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.token,
    this.vector,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<double>? vec;
    if (json['vector'] != null) {
      vec = (json['vector'] as List).map((e) => (e as num).toDouble()).toList();
    }
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      role: (json['role'] as String) == 'docente' ? UserRole.docente : UserRole.alumno,
      token: json['token'] as String?,
      vector: vec,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role == UserRole.docente ? 'docente' : 'alumno',
        'token': token,
        'vector': vector,
      };
}
