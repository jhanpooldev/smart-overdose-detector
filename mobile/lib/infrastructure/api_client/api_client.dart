// lib/infrastructure/api_client/api_client.dart
//
// Cliente HTTP centralizado para el PMV2 del Smart Overdose Detector.
// Implementa:
//   - Base URL configurable (emulador / dispositivo físico / producción)
//   - Inyección automática de Bearer Token en todas las requests
//   - Manejo tipado de errores (ApiException)
//   - Retry automático en errores de red (3 intentos con backoff)
//   - Parsing de respuestas a modelos Dart tipados

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/biometric_signal_model.dart';
import '../../domain/models/iot_session_model.dart';
import '../../domain/models/patient_online_status_model.dart';
import '../auth/auth_service.dart';

// ── Excepción tipada ──────────────────────────────────────────────────────────
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? detail;

  const ApiException({
    this.statusCode,
    required this.message,
    this.detail,
  });

  @override
  String toString() => 'ApiException(${statusCode ?? "network"}): $message';
}

// ── Cliente HTTP Singleton ────────────────────────────────────────────────────
class ApiClient {
  // Singleton
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String get baseUrl => 'https://smart-overdose-detector-production.up.railway.app';
  String get _v1 => '$baseUrl/api/v1';
  String get _v2 => '$baseUrl/api/v2';


  // ── Headers con Auth ──────────────────────────────────────────────────────
  Map<String, String> get _authHeaders {
    final token = AuthService().token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Método base con retry ─────────────────────────────────────────────────
  Future<http.Response> _request(
    Future<http.Response> Function() requestFn, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        final response = await requestFn().timeout(const Duration(seconds: 10));
        return response;
      } on SocketException catch (e) {
        if (attempt >= maxRetries) {
          throw ApiException(
            message: 'Sin conexión al servidor. Verifica que el backend esté activo.',
            detail: e.message,
          );
        }
        await Future.delayed(retryDelay * attempt);
      } on TimeoutException {
        if (attempt >= maxRetries) {
          throw const ApiException(message: 'Tiempo de espera agotado');
        }
        await Future.delayed(retryDelay * attempt);
      }
    }
  }

  /// Parsea respuesta HTTP, lanzando ApiException en errores.
  dynamic _parse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String detail = '';
    try {
      final body = jsonDecode(response.body);
      detail = (body['detail'] ?? body['message'] ?? '').toString();
    } catch (_) {
      detail = response.body;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: _httpMessage(response.statusCode),
      detail: detail,
    );
  }

  String _httpMessage(int code) => switch (code) {
    400 => 'Solicitud inválida',
    401 => 'No autenticado. Inicia sesión nuevamente.',
    403 => 'Sin permisos para esta acción',
    404 => 'Recurso no encontrado',
    409 => 'Conflicto — el recurso ya existe',
    422 => 'Datos de entrada inválidos',
    500 => 'Error interno del servidor',
    _   => 'Error HTTP $code',
  };

  // ════════════════════════════════════════════════════════════════════════════
  // ENDPOINTS PMV2 — TELEMETRÍA IoT
  // ════════════════════════════════════════════════════════════════════════════

  /// RF04 — Enviar una lectura biométrica al stream IoT.
  Future<BiometricSignalResponse> postTelemetryStream({
    required String sessionToken,
    required String deviceId,
    required int heartRate,
    required int spo2,
    int? respRate,
    String statusMovement = 'UNKNOWN',
    DateTime? recordedAt,
  }) async {
    final response = await _request(() => http.post(
      Uri.parse('$_v2/telemetry/stream'),
      headers: _authHeaders,
      body: jsonEncode({
        'session_token':   sessionToken,
        'device_id':       deviceId,
        'heart_rate':      heartRate,
        'spo2':            spo2,
        if (respRate != null) 'resp_rate': respRate,
        'status_movement': statusMovement,
        if (recordedAt != null) 'recorded_at': recordedAt.toUtc().toIso8601String(),
      }),
    ));

    final data = _parse(response) as Map<String, dynamic>;
    return BiometricSignalResponse.fromJson(data);
  }

  /// RF04 — Crear sesión IoT (el paciente obtiene su token de 6 chars).
  Future<IoTSessionModel> createIoTSession() async {
    final response = await _request(() => http.post(
      Uri.parse('$_v2/telemetry/sessions'),
      headers: _authHeaders,
    ));
    final data = _parse(response) as Map<String, dynamic>;
    return IoTSessionModel.fromJson(data);
  }

  /// RF08 — Consultar estado de una sesión IoT por token.
  Future<IoTSessionModel> getSessionStatus(String token) async {
    final response = await _request(() => http.get(
      Uri.parse('$_v2/telemetry/sessions/$token'),
      headers: _authHeaders,
    ));
    final data = _parse(response) as Map<String, dynamic>;
    return IoTSessionModel.fromJson(data);
  }

  /// Supervisor — Estado online de un paciente (polling).
  Future<PatientOnlineStatusModel> getPatientOnlineStatus(String patientId) async {
    final response = await _request(() => http.get(
      Uri.parse('$_v2/telemetry/status/$patientId'),
      headers: _authHeaders,
    ));
    final data = _parse(response) as Map<String, dynamic>;
    return PatientOnlineStatusModel.fromJson(data);
  }

  /// RF13 — Historial biométrico con rango de timestamps.
  Future<List<BiometricSignalResponse>> getSignalHistory({
    required String patientId,
    int limit = 100,
    DateTime? fromTs,
    DateTime? toTs,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      if (fromTs != null) 'from_ts': fromTs.toUtc().toIso8601String(),
      if (toTs   != null) 'to_ts':   toTs.toUtc().toIso8601String(),
    };

    final uri = Uri.parse('$_v2/telemetry/history/$patientId').replace(queryParameters: qp);
    final response = await _request(() => http.get(uri, headers: _authHeaders));
    final list = _parse(response) as List<dynamic>;
    return list.map((e) => BiometricSignalResponse.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ENDPOINTS PMV1 (compatibilidad)
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAlerts({
    required String patientId,
    int limit = 20,
  }) async {
    final response = await _request(() => http.get(
      Uri.parse('$_v1/alerts?patient_id=$patientId&limit=$limit'),
      headers: _authHeaders,
    ));
    final list = _parse(response) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getContacts() async {
    final response = await _request(() => http.get(
      Uri.parse('$_v1/contacts/'),
      headers: _authHeaders,
    ));
    final list = _parse(response) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }
}
