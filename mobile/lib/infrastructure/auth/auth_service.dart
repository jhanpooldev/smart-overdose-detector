// lib/infrastructure/auth/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/user.dart';

class AuthService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? currentUser;
  String? token;

  // Cambia esto a la IP de tu computadora si usas un dispositivo real, 
  // o a 10.0.2.2 si usas emulador Android
  final String baseUrl = "http://10.0.2.2:8000/api/v1/auth";

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['access_token'];
        currentUser = User.fromJson(data);
        return true;
      }
      return false;
    } catch (e) {
      print("Login error: \$e");
      return false;
    }
  }

  void logout() {
    currentUser = null;
    token = null;
  }
}
