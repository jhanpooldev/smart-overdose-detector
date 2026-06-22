// lib/infrastructure/telemetry/telemetry_service.dart
//
// Servicio de telemetría IoT — PMV2 (RF04/RF08).
//
// Responsabilidades:
//   1. Crear y mantener la sesión IoT (token 6 chars).
//   2. Enviar lecturas biométricas al backend (/api/v2/telemetry/stream).
//   3. Gestionar el estado del stream (CONNECTED/DISCONNECTED/STREAM_ERROR).
//   4. Detectar pérdida de conexión si no hay ACK en N segundos.
//   5. Exponer un Stream<BiometricSignalResponse> para la UI.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../domain/models/biometric_signal_model.dart';
import '../../domain/models/iot_session_model.dart';
import '../api_client/api_client.dart';
import '../sensors/simulated_sensor/simulated_sensor_adapter.dart';
import '../auth/auth_service.dart';

// ── Estado del stream ─────────────────────────────────────────────────────────
enum StreamConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

// ── Evento de estado de conexión ──────────────────────────────────────────────
class StreamStateEvent {
  final StreamConnectionState state;
  final String? errorMessage;
  final DateTime timestamp;

  StreamStateEvent({
    required this.state,
    this.errorMessage,
  }) : timestamp = DateTime.now();
}

// ── Servicio principal ────────────────────────────────────────────────────────
class TelemetryService {
  // Singleton
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  final ApiClient _api = ApiClient();
  final _uuid = const Uuid();

  // Stream controllers
  final _signalController = StreamController<BiometricSignalResponse>.broadcast();
  final _stateController  = StreamController<StreamStateEvent>.broadcast();

  /// Stream de señales biométricas procesadas — suscribirse en la UI.
  Stream<BiometricSignalResponse> get signalStream => _signalController.stream;

  /// Stream de cambios de estado de conexión IoT.
  Stream<StreamStateEvent> get connectionStateStream => _stateController.stream;

  // Estado interno
  IoTSessionModel? _currentSession;
  StreamConnectionState _state = StreamConnectionState.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  String? _deviceId;
  bool _isDisposed = false;

  IoTSessionModel? get currentSession => _currentSession;
  StreamConnectionState get connectionState => _state;
  bool get isConnected => _state == StreamConnectionState.connected;

  // ── Simulación ────────────────────────────────────────────────────────────
  bool isSimulated = false;
  final SimulatedSensorAdapter _sensor = SimulatedSensorAdapter();
  StreamSubscription? _sensorSub;

  // Bandera de excepciones para desactivar el monitoreo de inmovilidad
  bool exceptionsActive = false;

  void startSimulation() async {
    isSimulated = true;
    _sensorSub?.cancel();
    try { await startSession(); } catch (_) {}
    _sensorSub = _sensor.biometricStream.listen((raw) {
      sendReading(
        heartRate: raw.bpm,
        spo2: raw.spo2.round(),
        statusMovement: raw.activity == 1 ? 'WALKING' : 'STILL',
        mobility: raw.mobility,
      );
    });
  }

  void stopSimulation() {
    isSimulated = false;
    _sensorSub?.cancel();
    _sensor.stopSimulation();
  }

  void setScenario(ScenarioType type) => _sensor.setScenario(type);

  // ── Ciclo de vida ─────────────────────────────────────────────────────────

  /// Inicializa una sesión IoT y prepara el servicio para enviar telemetría.
  Future<IoTSessionModel> startSession() async {
    _deviceId ??= _uuid.v4();
    _setConnectionState(StreamConnectionState.connecting);

    try {
      _currentSession = await _api.createIoTSession();
      _setConnectionState(StreamConnectionState.connected);
      debugPrint('✅ Sesión IoT iniciada — token: ${_currentSession!.sessionToken}');
      return _currentSession!;
    } catch (e) {
      _setConnectionState(StreamConnectionState.error, error: e.toString());
      rethrow;
    }
  }

  /// Envía una lectura biométrica y actualiza el estado del stream.
  /// Retorna el resultado procesado por el backend (nivel de riesgo, etc.).
  Future<BiometricSignalResponse?> sendReading({
    required int heartRate,
    required int spo2,
    int? respRate,
    String statusMovement = 'UNKNOWN',
    DateTime? recordedAt,
    double? mobility,
  }) async {
    if (_currentSession == null) {
      debugPrint('⚠️ TelemetryService: Sin sesión activa. Llama a startSession() primero.');
      return null;
    }

    try {
      final result = await _api.postTelemetryStream(
        sessionToken:   _currentSession!.sessionToken,
        deviceId:       _deviceId!,
        heartRate:      heartRate,
        spo2:           spo2,
        respRate:       respRate,
        statusMovement: statusMovement,
        recordedAt:     recordedAt ?? DateTime.now().toUtc(),
      );

      // Integrar la movilidad a la respuesta final
      final finalResult = result.copyWith(
        mobility: mobility ?? (statusMovement == 'WALKING' ? 75.0 : 5.0),
      );

      // Publicar señal procesada en el stream de la UI
      if (!_isDisposed) {
        _signalController.add(finalResult);
      }

      if (_state != StreamConnectionState.connected) {
        _setConnectionState(StreamConnectionState.connected);
      }

      return finalResult;
    } on ApiException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 401) {
        // Token inválido → reiniciar sesión
        _currentSession = null;
        _setConnectionState(StreamConnectionState.disconnected);
      } else {
        _setConnectionState(StreamConnectionState.error, error: e.message);
      }
      return null;
    } catch (e) {
      _setConnectionState(StreamConnectionState.error, error: e.toString());
      return null;
    }
  }

  /// Desconecta la sesión actual limpiamente.
  void disconnect() {
    stopSimulation();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _currentSession = null;
    _setConnectionState(StreamConnectionState.disconnected);
    debugPrint('🔌 Sesión IoT desconectada');
  }

  /// Libera recursos al cerrar la pantalla.
  void dispose() {
    _isDisposed = true;
    disconnect();
    _signalController.close();
    _stateController.close();
  }

  // ── Helpers privados ───────────────────────────────────────────────────────
  void _setConnectionState(StreamConnectionState state, {String? error}) {
    _state = state;
    if (!_isDisposed && !_stateController.isClosed) {
      _stateController.add(StreamStateEvent(state: state, errorMessage: error));
    }
  }
}
