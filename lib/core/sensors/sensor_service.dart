// lib/core/sensors/sensor_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'orientation_service.dart';
import 'angle_filter_service.dart';
import 'gyro_service.dart';

/// Main service that coordinates between different sensor services
class SensorService extends ChangeNotifier {
  // Delegated services
  final OrientationService _orientationService = OrientationService();
  final AngleFilterService _angleFilterService = AngleFilterService();
  final GyroService _gyroService = GyroService();

  // --- Public interface (read-only) ---
  // Orientation (degrees)
  double? get roll => _orientationService.roll;
  double? get pitch => _orientationService.pitch;
  double? get yaw => _orientationService.yaw;

  // Gyro rates (deg/s)
  double? get gyroRoll => _gyroService.rollRate;
  double? get gyroPitch => _gyroService.pitchRate;
  double? get gyroYaw => _gyroService.yawRate;

  // Raw sensor data
  double? get accX => _orientationService.accX;
  double? get accY => _orientationService.accY;
  double? get accZ => _orientationService.accZ;
  double? get magX => _orientationService.magX;
  double? get magY => _orientationService.magY;
  double? get magZ => _orientationService.magZ;

  // Filtered angles
  double? get angleRollEst => _angleFilterService.roll;
  double? get anglePitchEst => _angleFilterService.pitch;
  
  /// Calibrate the sensors to use the current orientation as the new zero
  Future<void> calibrateZero() async {
    if (roll != null && pitch != null && yaw != null) {
      _orientationService.calibrateZero(roll!, pitch!, yaw!);
      _angleFilterService.reset();
      notifyListeners();
    }
  }

  bool _listening = false;
  StreamSubscription<List<double>>? _orientationSub;
  static const _updateInterval = Duration(milliseconds: 50);
  DateTime? _lastUpdateTime;

  /// Start listening to device sensors through delegated services
  Future<void> startListening() async {
    if (_listening) return;
    _listening = true;
    _lastUpdateTime = null;

    try {
      // Start all services
      await _orientationService.start();
      
      // Subscribe to orientation updates
      _orientationSub = _orientationService.orientationStream.listen((orientation) {
        // Throttle updates to UI
        final now = DateTime.now();
        if (_lastUpdateTime == null || now.difference(_lastUpdateTime!) >= _updateInterval) {
          _lastUpdateTime = now;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Error starting sensor services: $e');
      _listening = false;
      rethrow;
    }
  }

  /// Reset all filters and estimators to zero
  void resetFilters() {
    _orientationService.reset();
    _angleFilterService.reset();
    notifyListeners();
  }
  
  /// Stop listening to sensor updates
  void stopListening() {
    if (!_listening) return;
    _listening = false;
    _orientationSub?.cancel();
    _orientationService.stop();
    _orientationSub = null;
    _lastUpdateTime = null;
  }

  /// Update the sensor service with new values (for external integration)
  void updateValues({
    double? rollDeg,
    double? pitchDeg,
    double? yawDeg,
    double? gyroRollDegPerSec,
    double? gyroPitchDegPerSec,
    double? gyroYawDegPerSec,
  }) {
    // Delegate to appropriate services
    if (rollDeg != null || pitchDeg != null || yawDeg != null) {
      _orientationService.updateOrientation(
        roll: rollDeg,
        pitch: pitchDeg,
        yaw: yawDeg,
      );
    }
    
    notifyListeners();
  }


  @override
  void dispose() {
    stopListening();
    _orientationSub?.cancel();
    super.dispose();
  }
}
