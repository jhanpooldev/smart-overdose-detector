class BiometricReading {
  final double spo2;
  final int bpm;
  final int activity;
  final DateTime timestamp;

  BiometricReading({
    required this.spo2,
    required this.bpm,
    required this.activity,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'BiometricReading(spo2: $spo2, bpm: $bpm, activity: $activity, timestamp: $timestamp)';
  }
}
