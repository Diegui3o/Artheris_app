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
      double x = event.x;
      double y = event.y;
      double z = event.z;

      double roll = atan2(y, z) * (180 / pi);
      double pitch = atan2(-x, sqrt(y * y + z * z)) * (180 / pi);

      _rollController.add(roll);
      _pitchController.add(pitch);
    });
  }

  void stopListening() {
    _rollController.close();
    _pitchController.close();
  }
}
