import 'dart:async';
import 'dart:math';

import '../../../domain/entities/biometric_reading.dart';
import '../../../domain/ports/i_sensor_adapter.dart';

enum ScenarioType {
  normal,
  moderate,
  critical,
}

class SimulatedSensorAdapter implements ISensorAdapter {
  ScenarioType _currentScenario = ScenarioType.normal;
  final _random = Random();
  bool _isRunning = false;
  
  // Stream controller to emit continuous data
  final _biometricController = StreamController<BiometricReading>.broadcast();

  SimulatedSensorAdapter() {
    _startSimulation();
  }

  void _startSimulation() {
    _isRunning = true;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      _biometricController.add(_generateForScenario(_currentScenario));
    });
  }

  void stopSimulation() {
    _isRunning = false;
    _biometricController.close();
  }

  @override
  Stream<BiometricReading> get biometricStream => _biometricController.stream;

  void setScenario(ScenarioType scenario) {
    _currentScenario = scenario;
  }
  
  ScenarioType get currentScenario => _currentScenario;

  BiometricReading _generateForScenario(ScenarioType scenario) {
    final now = DateTime.now();
    double spo2;
    int bpm;
    int activity;

    switch (scenario) {
      case ScenarioType.normal:
        // SpO2: 95 - 100
        spo2 = 95.0 + _random.nextDouble() * 5.0;
        // BPM: 60 - 100
        bpm = 60 + _random.nextInt(41);
        activity = 1;
        break;
      case ScenarioType.moderate:
        // SpO2: 90 - 94.9
        spo2 = 90.0 + _random.nextDouble() * 4.9;
        // BPM: 50 - 60
        bpm = 50 + _random.nextInt(11);
        activity = _random.nextBool() ? 1 : 0;
        break;
      case ScenarioType.critical:
        // SpO2: 70 - 81.9
        spo2 = 70.0 + _random.nextDouble() * 11.9;
        // BPM: 30 - 49
        bpm = 30 + _random.nextInt(20);
        activity = 0;
        break;
    }

    return BiometricReading(
      spo2: double.parse(spo2.toStringAsFixed(1)),
      bpm: bpm,
      activity: activity,
      timestamp: now,
    );
  }
}
