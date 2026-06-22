class BiometricReading {
  final double spo2;
  final int bpm;
  final int activity;
  final double mobility; // Porcentaje de movilidad (0.0 - 100.0)
  final DateTime timestamp;

  BiometricReading({
    required this.spo2,
    required this.bpm,
    required this.activity,
    required this.mobility,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'BiometricReading(spo2: $spo2, bpm: $bpm, activity: $activity, mobility: $mobility, timestamp: $timestamp)';
  }
}
