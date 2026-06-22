// lib/domain/models/biometric_signal_model.dart
//
// Modelo Dart para señales biométricas (RF04/05).
// Incluye fromJson, clasificación de riesgo en tiempo real y sugerencias clínicas (RF13).

import 'package:flutter/material.dart';

// ── Enum de nivel de riesgo (RF05) ───────────────────────────────────────────
enum RiskLevelV2 {
  normal,
  moderate,
  critical;

  static RiskLevelV2 fromString(String s) => switch (s.toUpperCase()) {
    'CRITICAL' => RiskLevelV2.critical,
    'MODERATE' => RiskLevelV2.moderate,
    _          => RiskLevelV2.normal,
  };

  String get label => switch (this) {
    RiskLevelV2.critical => 'Crítico',
    RiskLevelV2.moderate => 'Moderado',
    RiskLevelV2.normal   => 'Normal',
  };

  Color get color => switch (this) {
    RiskLevelV2.critical => const Color(0xFFEF4444),
    RiskLevelV2.moderate => const Color(0xFFF59E0B),
    RiskLevelV2.normal   => const Color(0xFF10B981),
  };
}

// ── Enum de movimiento (RF04) ─────────────────────────────────────────────────
enum MovementStatusV2 {
  still,
  walking,
  running,
  unknown;

  static MovementStatusV2 fromString(String s) => switch (s.toUpperCase()) {
    'STILL'   => MovementStatusV2.still,
    'WALKING' => MovementStatusV2.walking,
    'RUNNING' => MovementStatusV2.running,
    _         => MovementStatusV2.unknown,
  };

  String get label => switch (this) {
    MovementStatusV2.still   => 'Inmóvil',
    MovementStatusV2.walking => 'Caminando',
    MovementStatusV2.running => 'Corriendo',
    MovementStatusV2.unknown => 'Desconocido',
  };
}

// ── Modelo principal ───────────────────────────────────────────────────────────
class BiometricSignalResponse {
  final DateTime         time;
  final int              heartRate;
  final int              spo2;
  final int?             respRate;
  final MovementStatusV2 statusMovement;
  final RiskLevelV2      riskLevel;
  final bool             alertTriggered;
  final String           streamStatus;
  final String?          patientId;
  final double           mobility; // Porcentaje de movilidad (0.0 - 100.0)

  const BiometricSignalResponse({
    required this.time,
    required this.heartRate,
    required this.spo2,
    this.respRate,
    required this.statusMovement,
    required this.riskLevel,
    required this.alertTriggered,
    required this.streamStatus,
    this.patientId,
    required this.mobility,
  });

  factory BiometricSignalResponse.fromJson(Map<String, dynamic> json) {
    return BiometricSignalResponse(
      time: DateTime.parse(json['time'] ?? json['processed_at'] ?? DateTime.now().toIso8601String()),
      heartRate:     (json['heart_rate'] ?? json['bpm'] ?? 0) as int,
      spo2:          (json['spo2'] ?? 0) as int,
      respRate:      json['resp_rate'] as int?,
      statusMovement: MovementStatusV2.fromString(json['status_movement'] ?? 'UNKNOWN'),
      riskLevel:     RiskLevelV2.fromString(json['risk_level'] ?? 'NORMAL'),
      alertTriggered: (json['alert_triggered'] ?? false) as bool,
      streamStatus:  (json['stream_status'] ?? 'DISCONNECTED') as String,
      patientId:     json['patient_id'] as String?,
      mobility:      (json['mobility'] ?? (json['status_movement'] == 'WALKING' ? 75.0 : (json['status_movement'] == 'RUNNING' ? 95.0 : 5.0))).toDouble(),
    );
  }

  /// Clasificación local de riesgo (RF05) — sin necesidad de llamar al backend.
  static RiskLevelV2 classifyLocally(int heartRate, int spo2) {
    if (spo2 < 90 || heartRate < 50 || heartRate > 120) return RiskLevelV2.critical;
    if (spo2 < 95 || heartRate < 60 || heartRate > 100) return RiskLevelV2.moderate;
    return RiskLevelV2.normal;
  }

  /// Sugerencia clínica basada en los valores (RF13).
  String get clinicalSuggestion {
    if (spo2 < 82) return '⚠️ Hipoxemia severa — riesgo vital inmediato';
    if (spo2 < 90) return '⚠️ Hipoxemia moderada — requiere atención urgente';
    if (spo2 < 95) return 'ℹ️ SpO₂ ligeramente bajo — monitorear de cerca';
    if (heartRate < 50) return '⚠️ Bradicardia severa — posible sobredosis de opioides';
    if (heartRate < 60) return 'ℹ️ Bradicardia leve — vigilar frecuencia';
    if (heartRate > 120) return '⚠️ Taquicardia — evaluar causa';
    if (heartRate > 100) return 'ℹ️ Taquicardia leve — monitorear';
    return '✓ Parámetros dentro del rango normal';
  }

  BiometricSignalResponse copyWith({RiskLevelV2? riskLevel, double? mobility}) => BiometricSignalResponse(
    time:           time,
    heartRate:      heartRate,
    spo2:           spo2,
    respRate:       respRate,
    statusMovement: statusMovement,
    riskLevel:      riskLevel ?? this.riskLevel,
    alertTriggered: alertTriggered,
    streamStatus:   streamStatus,
    patientId:      patientId,
    mobility:       mobility ?? this.mobility,
  );
}
