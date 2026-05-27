// lib/domain/models/iot_session_model.dart
// Modelo Dart para sesiones IoT con token de 6 chars (RF04/RF08).

class IoTSessionModel {
  final String    sessionToken;
  final String    patientId;
  final String    streamStatus;
  final DateTime? lastHeartbeat;
  final DateTime? expiresAt;
  final bool      isActive;

  const IoTSessionModel({
    required this.sessionToken,
    required this.patientId,
    required this.streamStatus,
    this.lastHeartbeat,
    this.expiresAt,
    required this.isActive,
  });

  factory IoTSessionModel.fromJson(Map<String, dynamic> json) {
    return IoTSessionModel(
      sessionToken:  (json['session_token'] ?? '') as String,
      patientId:     (json['patient_id'] ?? '') as String,
      streamStatus:  (json['stream_status'] ?? 'DISCONNECTED') as String,
      lastHeartbeat: json['last_heartbeat'] != null
          ? DateTime.parse(json['last_heartbeat'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isActive: (json['is_active'] ?? false) as bool,
    );
  }

  bool get isConnected => streamStatus == 'CONNECTED';
  bool get isDisconnected => streamStatus == 'DISCONNECTED';
  bool get hasError => streamStatus == 'STREAM_ERROR';

  /// Tiempo restante antes de expirar la sesión.
  Duration? get timeRemaining {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }
}
