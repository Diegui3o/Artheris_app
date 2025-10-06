import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  // Singleton pattern
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  // Stream controllers for angles
  final StreamController<double> _rollController =
      StreamController<double>.broadcast();
  final StreamController<double> _pitchController =
      StreamController<double>.broadcast();

  // Streams for the angles
  Stream<double> get rollStream => _rollController.stream;
  Stream<double> get pitchStream => _pitchController.stream;

  void startListening() {
    print("Iniciando sensores...");
    accelerometerEventStream().listen((AccelerometerEvent event) {
      // Calculate roll and pitch from accelerometer data
      double accX = event.x;
      double accY = event.y;
      double accZ = event.z;

      double anglerollEst =
          atan2(accY, sqrt(accX * accX + accZ * accZ)) * 180.0 / pi;
      double anglepitchEst =
          -atan2(accX, sqrt(accY * accY + accZ * accZ)) * 180.0 / pi;

      _rollController.add(anglerollEst);
      _pitchController.add(anglepitchEst);
    });
  }

  void stopListening() {
    _rollController.close();
    _pitchController.close();
  }
}
