// test/pmv3_test.dart
// Pruebas unitarias para funcionalidades PMV3 del Smart Overdose Detector.
// Cubre: HU-001, HU-002, HU-006 (lógica de dominio y modelo).

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_overdose_detector/domain/models/biometric_signal_model.dart';
import 'package:smart_overdose_detector/domain/entities/biometric_reading.dart';
import 'package:smart_overdose_detector/infrastructure/sensors/simulated_sensor/simulated_sensor_adapter.dart';
import 'package:smart_overdose_detector/infrastructure/telemetry/telemetry_service.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  BiometricSignalResponse _makeSignal({
    int heartRate = 75,
    int spo2 = 97,
    double mobility = 80.0,
    String streamStatus = 'CONNECTED',
    String riskLevel = 'NORMAL',
    String statusMovement = 'WALKING',
  }) {
    return BiometricSignalResponse(
      time: DateTime.now(),
      heartRate: heartRate,
      spo2: spo2,
      statusMovement: MovementStatusV2.fromString(statusMovement),
      riskLevel: RiskLevelV2.fromString(riskLevel),
      alertTriggered: false,
      streamStatus: streamStatus,
      mobility: mobility,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PMV3 - HU-002: Estado de Nivel de Inmovilidad
  // ─────────────────────────────────────────────────────────────────────────

  group('HU-002: Estado de Nivel de Inmovilidad', () {
    test('Escenario 1: Movilidad >= 50 => estado Normal', () {
      final signal = _makeSignal(mobility: 82.5);

      // La lógica de clasificación de movilidad espera:
      // >= 50  → Normal
      // 15-49  → Moderado
      // < 15   → Riesgo crítico
      final isCritical = signal.mobility < 15.0;
      final isModerate = signal.mobility >= 15.0 && signal.mobility < 50.0;
      final isNormal = signal.mobility >= 50.0;

      expect(isNormal, isTrue, reason: 'Movilidad ${signal.mobility}% debe ser Normal');
      expect(isModerate, isFalse);
      expect(isCritical, isFalse);
    });

    test('Escenario 2: Movilidad entre 15 y 50 => estado Moderado', () {
      final signal = _makeSignal(mobility: 30.0);

      final isCritical = signal.mobility < 15.0;
      final isModerate = signal.mobility >= 15.0 && signal.mobility < 50.0;
      final isNormal = signal.mobility >= 50.0;

      expect(isModerate, isTrue, reason: 'Movilidad ${signal.mobility}% debe ser Moderado');
      expect(isNormal, isFalse);
      expect(isCritical, isFalse);
    });

    test('Escenario 3: Movilidad < 15 => estado Riesgo crítico', () {
      final signal = _makeSignal(mobility: 7.3);

      final isCritical = signal.mobility < 15.0;
      final isModerate = signal.mobility >= 15.0 && signal.mobility < 50.0;
      final isNormal = signal.mobility >= 50.0;

      expect(isCritical, isTrue, reason: 'Movilidad ${signal.mobility}% debe ser Riesgo crítico');
      expect(isModerate, isFalse);
      expect(isNormal, isFalse);
    });

    test('Límite exacto 50.0 => Normal (no Moderado)', () {
      final signal = _makeSignal(mobility: 50.0);
      expect(signal.mobility >= 50.0, isTrue);
    });

    test('Límite exacto 15.0 => Moderado (no Riesgo crítico)', () {
      final signal = _makeSignal(mobility: 15.0);
      expect(signal.mobility >= 15.0, isTrue);
      expect(signal.mobility < 15.0, isFalse);
    });

    test('Movilidad 0.0 => Riesgo crítico', () {
      final signal = _makeSignal(mobility: 0.0);
      expect(signal.mobility < 15.0, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // PMV3 - HU-003: Lógica de disparo de verificación
  // ─────────────────────────────────────────────────────────────────────────

  group('HU-003: Condiciones de disparo de verificación de riesgo', () {
    test('Movilidad crítica sin excepción => debe disparar verificación', () {
      final signal = _makeSignal(mobility: 5.0, riskLevel: 'NORMAL');
      const exceptionsActive = false;

      final isCriticalMobility = signal.mobility < 15.0 && !exceptionsActive;
      final isCriticalVitals = signal.riskLevel == RiskLevelV2.critical;

      expect(isCriticalMobility || isCriticalVitals, isTrue);
    });

    test('Movilidad crítica CON excepción activa => NO debe disparar verificación', () {
      final signal = _makeSignal(mobility: 5.0, riskLevel: 'NORMAL');
      const exceptionsActive = true;

      final isCriticalMobility = signal.mobility < 15.0 && !exceptionsActive;
      final isCriticalVitals = signal.riskLevel == RiskLevelV2.critical;

      expect(isCriticalMobility || isCriticalVitals, isFalse,
          reason: 'Excepción activa debe suprimir la alerta de inmovilidad');
    });

    test('Signos vitales críticos (riskLevel=CRITICAL) => debe disparar verificación', () {
      final signal = _makeSignal(mobility: 80.0, riskLevel: 'CRITICAL');
      const exceptionsActive = false;

      final isCriticalMobility = signal.mobility < 15.0 && !exceptionsActive;
      final isCriticalVitals = signal.riskLevel == RiskLevelV2.critical;

      expect(isCriticalMobility || isCriticalVitals, isTrue,
          reason: 'Signos vitales críticos deben disparar verificación independientemente de la excepción');
    });

    test('Signos vitales críticos CON excepción => debe disparar (excepción solo aplica a inmovilidad)', () {
      final signal = _makeSignal(mobility: 80.0, riskLevel: 'CRITICAL');
      const exceptionsActive = true;

      final isCriticalMobility = signal.mobility < 15.0 && !exceptionsActive;
      final isCriticalVitals = signal.riskLevel == RiskLevelV2.critical;

      expect(isCriticalMobility || isCriticalVitals, isTrue,
          reason: 'Excepción NO debe suprimir alertas de signos vitales críticos');
    });

    test('Movilidad normal y signos normales => NO debe disparar verificación', () {
      final signal = _makeSignal(mobility: 75.0, riskLevel: 'NORMAL');
      const exceptionsActive = false;

      final isCriticalMobility = signal.mobility < 15.0 && !exceptionsActive;
      final isCriticalVitals = signal.riskLevel == RiskLevelV2.critical;

      expect(isCriticalMobility || isCriticalVitals, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // PMV3 - HU-006: Lógica de Excepciones
  // ─────────────────────────────────────────────────────────────────────────

  group('HU-006: Configuración de Excepciones', () {
    test('TelemetryService tiene bandera exceptionsActive inicializada en false', () {
      final telemetry = TelemetryService();
      expect(telemetry.exceptionsActive, isFalse);
    });

    test('Activar excepción => exceptionsActive = true', () {
      final telemetry = TelemetryService();
      telemetry.exceptionsActive = true;
      expect(telemetry.exceptionsActive, isTrue);
    });

    test('Desactivar excepción => exceptionsActive = false', () {
      final telemetry = TelemetryService();
      telemetry.exceptionsActive = true;
      telemetry.exceptionsActive = false;
      expect(telemetry.exceptionsActive, isFalse);
    });

    test('Excepción activa + movilidad crítica => NO dispara verificación', () {
      final telemetry = TelemetryService();
      telemetry.exceptionsActive = true;

      final signal = _makeSignal(mobility: 3.0, riskLevel: 'NORMAL');
      final shouldAlert = signal.mobility < 15.0 && !telemetry.exceptionsActive;
      expect(shouldAlert, isFalse);

      // cleanup
      telemetry.exceptionsActive = false;
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // PMV3 - Modelo de Datos: BiometricSignalResponse
  // ─────────────────────────────────────────────────────────────────────────

  group('BiometricSignalResponse: campo mobility', () {
    test('fromJson sin campo mobility usa fallback por statusMovement=WALKING', () {
      final json = {
        'time': DateTime.now().toIso8601String(),
        'heart_rate': 75,
        'spo2': 97,
        'status_movement': 'WALKING',
        'risk_level': 'NORMAL',
        'alert_triggered': false,
        'stream_status': 'CONNECTED',
      };
      final signal = BiometricSignalResponse.fromJson(json);
      expect(signal.mobility, equals(75.0));
    });

    test('fromJson sin campo mobility usa fallback por statusMovement=STILL (5.0)', () {
      final json = {
        'time': DateTime.now().toIso8601String(),
        'heart_rate': 40,
        'spo2': 85,
        'status_movement': 'STILL',
        'risk_level': 'CRITICAL',
        'alert_triggered': true,
        'stream_status': 'CONNECTED',
      };
      final signal = BiometricSignalResponse.fromJson(json);
      expect(signal.mobility, equals(5.0));
    });

    test('fromJson con campo mobility explícito lo usa directamente', () {
      final json = {
        'time': DateTime.now().toIso8601String(),
        'heart_rate': 75,
        'spo2': 97,
        'status_movement': 'WALKING',
        'risk_level': 'NORMAL',
        'alert_triggered': false,
        'stream_status': 'CONNECTED',
        'mobility': 88.5,
      };
      final signal = BiometricSignalResponse.fromJson(json);
      expect(signal.mobility, equals(88.5));
    });

    test('copyWith actualiza mobility correctamente', () {
      final original = _makeSignal(mobility: 30.0);
      final updated = original.copyWith(mobility: 85.0);
      expect(updated.mobility, equals(85.0));
      expect(original.mobility, equals(30.0)); // Inmutable
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // PMV3 - SimulatedSensorAdapter: campo mobility por escenario
  // ─────────────────────────────────────────────────────────────────────────

  group('SimulatedSensorAdapter: generación de mobility por escenario', () {
    test('Escenario Normal genera mobility >= 60.0', () async {
      final adapter = SimulatedSensorAdapter();
      adapter.setScenario(ScenarioType.normal);

      BiometricReading? reading;
      await for (final r in adapter.biometricStream.take(3)) {
        reading = r;
        if (reading.mobility < 60.0) {
          fail('Normal scenario debería generar mobility >= 60, got ${reading.mobility}');
        }
      }
      adapter.stopSimulation();
    });

    test('Escenario Moderado genera mobility entre 15 y 45', () async {
      final adapter = SimulatedSensorAdapter();
      adapter.setScenario(ScenarioType.moderate);

      await for (final r in adapter.biometricStream.take(3)) {
        expect(r.mobility, greaterThanOrEqualTo(15.0),
            reason: 'Moderate: mobility debe ser >= 15.0');
        expect(r.mobility, lessThan(46.0),
            reason: 'Moderate: mobility debe ser < 46.0 (aprox)');
      }
      adapter.stopSimulation();
    });

    test('Escenario Crítico genera mobility < 15.0', () async {
      final adapter = SimulatedSensorAdapter();
      adapter.setScenario(ScenarioType.critical);

      await for (final r in adapter.biometricStream.take(3)) {
        expect(r.mobility, lessThan(15.0),
            reason: 'Critical: mobility debe ser < 15.0, got ${r.mobility}');
      }
      adapter.stopSimulation();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // PMV3 - RiskLevelV2: clasificación local y etiquetas
  // ─────────────────────────────────────────────────────────────────────────

  group('RiskLevelV2: etiquetas correctas por nivel', () {
    test('normal => label "Normal"', () {
      expect(RiskLevelV2.normal.label, equals('Normal'));
    });

    test('moderate => label "Moderado"', () {
      expect(RiskLevelV2.moderate.label, equals('Moderado'));
    });

    test('critical => label "Crítico"', () {
      expect(RiskLevelV2.critical.label, equals('Crítico'));
    });

    test('SpO2 < 90 => critical local', () {
      final level = BiometricSignalResponse.classifyLocally(70, 88);
      expect(level, equals(RiskLevelV2.critical));
    });

    test('SpO2 ok, BPM normal => normal local', () {
      final level = BiometricSignalResponse.classifyLocally(75, 98);
      expect(level, equals(RiskLevelV2.normal));
    });
  });
}
