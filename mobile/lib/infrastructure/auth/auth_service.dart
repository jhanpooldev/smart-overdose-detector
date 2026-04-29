// lib/infrastructure/auth/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../domain/entities/user.dart';

class AuthService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? currentUser;
  String? token;

  // Se detectó el uso de emulador y dispositivos físicos.
  // Esta lógica intenta elegir la mejor IP automáticamente.
  String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:8000/api/v1/auth";
    // 10.0.2.2 es para el emulador de Android. 
    // Si usas un celular físico, cambia '10.0.2.2' por '192.168.1.36'
    return "http://10.0.2.2:8000/api/v1/auth";
  }

  Future<void> login(String email, String password) async {
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
        return;
      }
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? "Error de inicio de sesión");
    } catch (e) {
      print("Login error: $e");
      rethrow;
    }
  }

  Future<void> register(String email, String password, String name, {String? supervisorEmail}) async {
    try {
      final body = {'email': email, 'password': password, 'name': name};
      if (supervisorEmail != null && supervisorEmail.isNotEmpty) {
        body['supervisor_email'] = supervisorEmail;
      }
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['access_token'];
        currentUser = User.fromJson(data);
        return;
      }
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? "Error al registrar cuenta");
    } catch (e) {
      print("Register error: $e");
      rethrow;
    }
  }

  void logout() {
    currentUser = null;
    token = null;
  }
}
