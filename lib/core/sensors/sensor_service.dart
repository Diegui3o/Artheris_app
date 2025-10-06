// lib/core/sensors/sensor_service.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService extends ChangeNotifier {
  // --- Estimated angles (from your filter) ---
  double? angleRollEst;
  double? anglePitchEst;

  // --- Orientation fused (degrees) ---
  double? roll;
  double? pitch;
  double? yaw;

  // --- Gyro rates (deg/s) ---
  double? gyroRoll;
  double? gyroPitch;
  double? gyroYaw;

  // --- Accelerometer readings (m/s^2 approx or raw depending on source) ---
  double? accX;
  double? accY;
  double? accZ;

  // Magnetometer (raw)
  double? magX;
  double? magY;
  double? magZ;

  // Offsets applied during calibrateZero (degrees)
  double _rollOffset = 0.0;
  double _pitchOffset = 0.0;
  double _yawOffset = 0.0;

  // Sensor subscriptions
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  // Whether the service is currently listening
  bool _listening = false;

  // For throttling updates to UI
  static const _updateInterval = Duration(milliseconds: 50); // 20 Hz
  DateTime? _lastUpdateTime;

  // Orientation internal state (radians)
  double _rollRad = 0.0;
  double _pitchRad = 0.0;
  double _yawRad = 0.0;

  // Fusion parameters (tune these)
  final double alpha = 0.98; // trust gyro vs accel for roll/pitch
  final double yawBeta = 0.02; // magnetometer correction strength for yaw

  // For dt computation
  DateTime? _lastGyroTime;

  /// Start listening to device sensors and compute orientation
  void startListening() {
    if (_listening) return;
    _listening = true;
    _lastUpdateTime = DateTime.now();
    _lastGyroTime = null;

    // Accelerometer: update last acc values used for correction
    _accelSub = accelerometerEvents.listen((AccelerometerEvent a) {
      accX = a.x;
      accY = a.y;
      accZ = a.z;
      // We do not call notifyListeners() here (will be triggered by gyro integration)
    });

    // Magnetometer: store last mag for yaw correction
    _magSub = magnetometerEvents.listen((MagnetometerEvent m) {
      magX = m.x;
      magY = m.y;
      magZ = m.z;
    });

    // Gyroscope: main driver — integrate and fuse
    _gyroSub = gyroscopeEvents.listen((GyroscopeEvent e) {
      final now = DateTime.now();
      // sensors_plus gives gyro in rad/s
      final gx = e.x;
      final gy = e.y;
      final gz = e.z;

      // Compute dt (seconds)
      double dt;
      if (_lastGyroTime == null) {
        dt = 0.0;
      } else {
        dt = now.difference(_lastGyroTime!).inMicroseconds / 1e6;
      }
      _lastGyroTime = now;

      // Save gyro in deg/s for UI
      gyroRoll = gx * 180.0 / pi;
      gyroPitch = gy * 180.0 / pi;
      gyroYaw = gz * 180.0 / pi;

      if (dt > 0) {
        // Integrate gyro to update orientation (radians)
        _rollRad += gx * dt;
        _pitchRad += gy * dt;
        _yawRad += gz * dt;

        // If accelerometer available, compute roll/pitch from accel and fuse
        if (accX != null && accY != null && accZ != null) {
          final ax = accX!;
          final ay = accY!;
          final az = accZ!;
          // compute accel-based angles (radians)
          final rollAcc = atan2(ay, az);
          final pitchAcc = atan2(-ax, sqrt(ay * ay + az * az));

          // Complementary filter
          _rollRad = alpha * _rollRad + (1 - alpha) * rollAcc;
          _pitchRad = alpha * _pitchRad + (1 - alpha) * pitchAcc;
        }

        // If magnetometer available, compute magnetic yaw and fuse
        if (magX != null && magY != null && magZ != null) {
          // Use current roll/pitch to de-tilt the magnetometer
          final mx = magX!;
          final my = magY!;
          final mz = magZ!;

          // de-tilt formulas: project magnetic vector into horizontal plane
          final cosR = cos(_rollRad);
          final sinR = sin(_rollRad);
          final cosP = cos(_pitchRad);
          final sinP = sin(_pitchRad);

          final mx2 = mx * cosP + mz * sinP;
          final my2 = mx * sinR * sinP + my * cosR - mz * sinR * cosP;

          final yawMag = atan2(-my2, mx2); // radians

          // Fuse yaw integrated with magnetometer heading
          _yawRad = (1 - yawBeta) * _yawRad + yawBeta * yawMag;
        }

        // Update public degrees applying offsets
        roll = _radToDeg(_rollRad) - _rollOffset;
        pitch = _radToDeg(_pitchRad) - _pitchOffset;
        yaw = _normalizeAngleDeg(_radToDeg(_yawRad) - _yawOffset);

        // Throttle notifications to UI
        final now2 = DateTime.now();
        if (_lastUpdateTime == null ||
            now2.difference(_lastUpdateTime!) >= _updateInterval) {
          _lastUpdateTime = now2;
          notifyListeners();
        }
      } else {
        // No dt yet — still update gyro values for UI
        final now2 = DateTime.now();
        if (_lastUpdateTime == null ||
            now2.difference(_lastUpdateTime!) >= _updateInterval) {
          _lastUpdateTime = now2;
          notifyListeners();
        }
      }
    });
  }

  /// Stops listening to sensors
  void stopListening() {
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _magSub?.cancel();
    _gyroSub = null;
    _accelSub = null;
    _magSub = null;
    _listening = false;
  }

  /// Calibrate: set the current roll/pitch/yaw as the new zero.
  Future<void> calibrateZero() async {
    _rollOffset = roll ?? 0.0;
    _pitchOffset = pitch ?? 0.0;
    _yawOffset = yaw ?? 0.0;

    if (roll != null) roll = roll! - _rollOffset;
    if (pitch != null) pitch = pitch! - _pitchOffset;
    if (yaw != null) yaw = _normalizeAngleDeg((yaw ?? 0.0) - _yawOffset);

    notifyListeners();
  }

  /// Reset filters / estimators (set estimations to zero)
  void resetFilters() {
    angleRollEst = 0.0;
    anglePitchEst = 0.0;
    roll = 0.0;
    pitch = 0.0;
    yaw = 0.0;
    _rollRad = 0.0;
    _pitchRad = 0.0;
    _yawRad = 0.0;
    notifyListeners();
  }

  /// Helper to update multiple values at once (e.g. from your AngleFilterService)
  void updateValues({
    double? angleRollEst,
    double? anglePitchEst,
    double? rollDeg,
    double? pitchDeg,
    double? yawDeg,
    double? gyroRollDegPerSec,
    double? gyroPitchDegPerSec,
    double? gyroYawDegPerSec,
    double? accXVal,
    double? accYVal,
    double? accZVal,
  }) {
    if (angleRollEst != null) this.angleRollEst = angleRollEst;
    if (anglePitchEst != null) this.anglePitchEst = anglePitchEst;

    if (rollDeg != null) {
      roll = rollDeg - _rollOffset;
      _rollRad = rollDeg * pi / 180.0;
    }
    if (pitchDeg != null) {
      pitch = pitchDeg - _pitchOffset;
      _pitchRad = pitchDeg * pi / 180.0;
    }
    if (yawDeg != null) {
      yaw = _normalizeAngleDeg(yawDeg - _yawOffset);
      _yawRad = yawDeg * pi / 180.0;
    }

    if (gyroRollDegPerSec != null) gyroRoll = gyroRollDegPerSec;
    if (gyroPitchDegPerSec != null) gyroPitch = gyroPitchDegPerSec;
    if (gyroYawDegPerSec != null) gyroYaw = gyroYawDegPerSec;

    if (accXVal != null) accX = accXVal;
    if (accYVal != null) accY = accYVal;
    if (accZVal != null) accZ = accZVal;

    notifyListeners();
  }

  double _normalizeAngleDeg(double a) {
    double x = a;
    while (x > 180.0) x -= 360.0;
    while (x <= -180.0) x += 360.0;
    return x;
  }

  double _radToDeg(double r) => r * 180.0 / pi;

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
