// lib/domain/entities/user.dart
enum Role { supervisor, paciente }

class User {
  final String id;
  final String email;
  final Role role;
  final String? supervisorEmail;

  User({required this.id, required this.email, required this.role, this.supervisorEmail});

  static Role _parseRole(String roleStr) {
    switch (roleStr.toUpperCase()) {
      case 'SUPERVISOR': return Role.supervisor;
      case 'PACIENTE': return Role.paciente;
      default: return Role.paciente;
    }
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: _parseRole(json['role'] ?? 'PACIENTE'),
      supervisorEmail: json['supervisor_email'],
    );
  }
}
