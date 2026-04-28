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

  // Usa 127.0.0.1 para Web, o 10.0.2.2 para emulador Android
  final String baseUrl = kIsWeb ? "http://127.0.0.1:8000/api/v1/auth" : "http://10.0.2.2:8000/api/v1/auth";

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

  Future<void> register(String email, String password, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'name': name}),
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
