// lib/domain/entities/user.dart
enum Role { admin, doctor, patient, family }

class User {
  final String email;
  final Role role;

  User({required this.email, required this.role});

  static Role _parseRole(String roleStr) {
    switch (roleStr.toUpperCase()) {
      case 'ADMIN': return Role.admin;
      case 'DOCTOR': return Role.doctor;
      case 'PATIENT': return Role.patient;
      case 'FAMILY': return Role.family;
      default: return Role.patient;
    }
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] ?? '',
      role: _parseRole(json['role'] ?? 'PATIENT'),
    );
  }
}
