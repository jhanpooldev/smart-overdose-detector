import '../entities/biometric_reading.dart';

abstract class ISensorAdapter {
  Stream<BiometricReading> get biometricStream;
}
