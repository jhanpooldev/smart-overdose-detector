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

  // ─── Configuración de URL ──────────────────────────────────────────────────
  // Para emulador de Android: 10.0.2.2 (localhost del host)
  // Para celular físico (APK): Cambia a la IP local de tu PC (ej: 192.168.1.36)
  static const String _emulatorIp = '10.0.2.2';
  static const int _port = 8000;

  String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:$_port/api/v1/auth';
    return 'http://$_emulatorIp:$_port/api/v1/auth';
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

  Future<void> register(String email, String password, String name, {
    String? supervisorEmail,
    int? edad,
    double? peso,
    double? altura,
    String? sexo,
    String role = 'Paciente',
  }) async {
    try {
      final bodyMap = <String, dynamic>{
        'email': email,
        'password': password,
        'name': name,
        'role': role.toUpperCase(),
      };
      if (supervisorEmail != null && supervisorEmail.isNotEmpty) bodyMap['supervisor_email'] = supervisorEmail;
      if (edad != null) bodyMap['edad'] = edad;
      if (peso != null) bodyMap['peso'] = peso;
      if (altura != null) bodyMap['altura'] = altura;
      if (sexo != null) bodyMap['sexo'] = sexo;

      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyMap),
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
