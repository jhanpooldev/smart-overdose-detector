// lib/domain/models/patient_online_status_model.dart
// Modelo Dart para estado online del paciente — consulta del Supervisor (RF).

class PatientOnlineStatusModel {
  final String    patientId;
  final bool      statusOnline;
  final String    streamStatus;
  final DateTime? lastSeen;

  const PatientOnlineStatusModel({
    required this.patientId,
    required this.statusOnline,
    required this.streamStatus,
    this.lastSeen,
  });

  factory PatientOnlineStatusModel.fromJson(Map<String, dynamic> json) {
    return PatientOnlineStatusModel(
      patientId:    (json['patient_id'] ?? '') as String,
      statusOnline: (json['status_online'] ?? false) as bool,
      streamStatus: (json['stream_status'] ?? 'DISCONNECTED') as String,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
    );
  }

  /// Descripción amigable del tiempo desde la última señal.
  String get lastSeenLabel {
    if (lastSeen == null) return 'Sin datos';
    final diff = DateTime.now().toUtc().difference(lastSeen!);
    if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    return 'Hace ${diff.inHours}h';
  }
}
