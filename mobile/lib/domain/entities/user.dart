// lib/domain/entities/user.dart
enum Role { supervisor, paciente }

class User {
  final String email;
  final Role role;

  User({required this.email, required this.role});

  static Role _parseRole(String roleStr) {
    switch (roleStr.toUpperCase()) {
      case 'SUPERVISOR': return Role.supervisor;
      case 'PACIENTE': return Role.paciente;
      default: return Role.paciente;
    }
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] ?? '',
      role: _parseRole(json['role'] ?? 'PACIENTE'),
    );
  }
}
