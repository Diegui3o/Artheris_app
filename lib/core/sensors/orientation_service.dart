// lib/core/sensors/orientation_service.dart

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart'; // Importa los tipos AccelerometerEvent, GyroscopeEvent, MagnetometerEvent

class OrientationService {
  // Constantes de fusión: peso del gyro vs corrección del acelerómetro/magnetómetro
  final double alpha;
  final double yawBeta;

  // Estado estimado (ángulos en radianes)
  double _roll = 0.0;
  double _pitch = 0.0;
  double _yaw = 0.0;

  // Streams de sensores
  final Stream<AccelerometerEvent> accelStream;
  final Stream<GyroscopeEvent> gyroStream;
  final Stream<MagnetometerEvent> magStream;

  // Últimas lecturas de sensores
  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;
  double _mx = 0, _my = 0, _mz = 0;

  DateTime? _lastTime;

  final StreamController<List<double>> _orientationController =
      StreamController<List<double>>.broadcast();

  Stream<List<double>> get orientationStream => _orientationController.stream;

  OrientationService({
    this.alpha = 0.98,
    this.yawBeta = 0.02,
    required this.accelStream,
    required this.gyroStream,
    required this.magStream,
  }) {
    _subscribe();
  }

  void _subscribe() {
    accelStream.listen((AccelerometerEvent a) {
      _ax = a.x;
      _ay = a.y;
      _az = a.z;
    });

    gyroStream.listen((GyroscopeEvent g) {
      _gx = g.x;
      _gy = g.y;
      _gz = g.z;
      _processFusion();
    });

    magStream.listen((MagnetometerEvent m) {
      _mx = m.x;
      _my = m.y;
      _mz = m.z;
    });
  }

  void _processFusion() {
    final now = DateTime.now();
    if (_lastTime == null) {
      _lastTime = now;
      return;
    }
    final dt = now.difference(_lastTime!).inMicroseconds / 1e6;
    _lastTime = now;

    // Integrar giroscopio
    _roll += _gx * dt;
    _pitch += _gy * dt;
    _yaw += _gz * dt;

    // Corrección roll/pitch con acelerómetro
    double rollAcc = atan2(_ay, _az);
    double pitchAcc = atan2(-_ax, sqrt(_ay * _ay + _az * _az));

    _roll = alpha * _roll + (1 - alpha) * rollAcc;
    _pitch = alpha * _pitch + (1 - alpha) * pitchAcc;

    // Corrección yaw usando magnetómetro
    // Proyección al plano horizontal considerando roll/pitch
    double mx2 = _mx * cos(_pitch) + _mz * sin(_pitch);
    double my2 =
        _mx * sin(_roll) * sin(_pitch) +
        _my * cos(_roll) -
        _mz * sin(_roll) * cos(_pitch);
    double yawMag = atan2(-my2, mx2);

    _yaw = (1 - yawBeta) * _yaw + yawBeta * yawMag;

    _emitOrientation();
  }

  void _emitOrientation() {
    _orientationController.add([_roll, _pitch, _yaw]);
  }

  void dispose() {
    _orientationController.close();
  }
}
