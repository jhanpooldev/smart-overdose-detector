// lib/infrastructure/auth/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../domain/entities/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
class AuthService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? currentUser;
  String? token;
  final _storage = const FlutterSecureStorage();

  String get baseUrl {
    return 'https://smart-overdose-detector-production.up.railway.app/api/v1/auth';
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
        
        await _storage.write(key: 'saved_email', value: email);
        await _storage.write(key: 'saved_password', value: password);
        
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
    String? telefono,
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
      if (telefono != null) bodyMap['telefono'] = telefono;

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

  Future<void> logout() async {
    currentUser = null;
    token = null;
    await _storage.delete(key: 'saved_email');
    await _storage.delete(key: 'saved_password');
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    final email = await _storage.read(key: 'saved_email');
    final password = await _storage.read(key: 'saved_password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }
}
