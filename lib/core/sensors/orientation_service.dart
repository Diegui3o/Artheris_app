// lib/core/sensors/orientation_service.dart

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Service that provides device orientation using sensor fusion
class OrientationService {
  // Raw sensor values
  double? accX;
  double? accY;
  double? accZ;
  double? magX;
  double? magY;
  double? magZ;
  
  // Processed orientation in degrees
  double? roll;
  double? pitch;
  double? yaw;
  
  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  
  // Timestamp for delta time calculation
  DateTime? _lastUpdateTime;
  
  // Complementary filter coefficient (0-1)
  final double _alpha = 0.98;

  /// Stream que emite [roll, pitch, yaw] en **radianes** (valores dobles).
  final StreamController<List<double>> _controller =
      StreamController<List<double>>.broadcast();

  Stream<List<double>> get orientationStream => _controller.stream;

  /// Offsets en grados para calibración (lo que defines como “nuevo cero”)
  double _rollOffsetDeg = 0.0;
  double _pitchOffsetDeg = 0.0;
  double _yawOffsetDeg = 0.0;

  /// Initialize the service and start listening to sensors
  Future<void> start() async {
    _lastUpdateTime = DateTime.now();
    
    // Listen to accelerometer
    _accelSub = accelerometerEvents.listen((AccelerometerEvent event) {
      accX = event.x;
      accY = event.y;
      accZ = event.z;
      _updateOrientation();
    });
    
    // Listen to magnetometer
    _magSub = magnetometerEvents.listen((MagnetometerEvent event) {
      magX = event.x;
      magY = event.y;
      magZ = event.z;
    });
    
    // Listen to gyroscope
    _gyroSub = gyroscopeEvents.listen((GyroscopeEvent event) {
      final now = DateTime.now();
      final double dt = _lastUpdateTime != null 
          ? (now.difference(_lastUpdateTime!).inMilliseconds / 1000.0) 
          : 0.0;
      _lastUpdateTime = now;
      
      if (dt > 0) {
        // Integrate gyro data (convert from rad/s to deg/s and multiply by dt)
        double gyroRoll = event.x * (180 / pi) * dt;
        double gyroPitch = event.y * (180 / pi) * dt;
        double gyroYaw = event.z * (180 / pi) * dt;
        
        // Apply gyro data with complementary filter
        if (roll != null && pitch != null && yaw != null) {
          roll = _alpha * (roll! + gyroRoll) + (1 - _alpha) * _calculateAccelerometerRoll();
          pitch = _alpha * (pitch! + gyroPitch) + (1 - _alpha) * _calculateAccelerometerPitch();
          
          // For yaw, we need magnetometer data
          if (magX != null && magY != null && magZ != null) {
            yaw = _alpha * (yaw! + gyroYaw) + (1 - _alpha) * _calculateMagnetometerYaw();
          } else {
            yaw = yaw! + gyroYaw;
          }
          
          // Apply offsets
          roll = roll! - _rollOffsetDeg;
          pitch = pitch! - _pitchOffsetDeg;
          yaw = _normalizeAngleDeg(yaw! - _yawOffsetDeg);
          
          // Notify listeners
          _controller.add([
            roll! * (pi / 180.0),
            pitch! * (pi / 180.0),
            yaw! * (pi / 180.0),
          ]);
        } else {
          // Initialize with accelerometer if first run
          roll = _calculateAccelerometerRoll();
          pitch = _calculateAccelerometerPitch();
          yaw = 0.0;
        }
      }
    });
  }

  /// Stop listening to sensors
  void stop() {
    _accelSub?.cancel();
    _magSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _magSub = null;
    _gyroSub = null;
    _lastUpdateTime = null;
  }
  
  /// Actualiza la orientación manualmente (para pruebas/external input)
  void updateOrientation({double? roll, double? pitch, double? yaw}) {
    if (roll != null) this.roll = roll;
    if (pitch != null) this.pitch = pitch;
    if (yaw != null) this.yaw = yaw;
    _controller.add([
      (roll ?? this.roll ?? 0.0) * (pi / 180.0),
      (pitch ?? this.pitch ?? 0.0) * (pi / 180.0),
      (yaw ?? this.yaw ?? 0.0) * (pi / 180.0),
    ]);
  }
  
  /// Reinicia los valores de orientación
  void reset() {
    roll = 0.0;
    pitch = 0.0;
    yaw = 0.0;
    _rollOffsetDeg = 0.0;
    _pitchOffsetDeg = 0.0;
    _yawOffsetDeg = 0.0;
  }

  /// Calibrar: fijar los offsets tomando la orientación actual como nuevo cero.
  void calibrateZero(
    double currentRollDeg,
    double currentPitchDeg,
    double currentYawDeg,
  ) {
    _rollOffsetDeg = currentRollDeg;
    _pitchOffsetDeg = currentPitchDeg;
    // Normaliza yaw antes de guardarlo
    _yawOffsetDeg = _normalizeAngleDeg(currentYawDeg);
  }

  /// Calculate roll from accelerometer data (in degrees)
  double _calculateAccelerometerRoll() {
    if (accX == null || accY == null || accZ == null) return 0.0;
    return atan2(accY!, sqrt(accX! * accX! + accZ! * accZ!)) * (180.0 / pi);
  }
  
  /// Calculate pitch from accelerometer data (in degrees)
  double _calculateAccelerometerPitch() {
    if (accX == null || accY == null || accZ == null) return 0.0;
    return -atan2(accX!, sqrt(accY! * accY! + accZ! * accZ!)) * (180.0 / pi);
  }
  
  /// Calculate yaw from magnetometer data (in degrees)
  double _calculateMagnetometerYaw() {
    if (magX == null || magY == null || magZ == null || roll == null || pitch == null) return 0.0;
    
    // Convert to radians for calculations
    double rollRad = roll! * (pi / 180.0);
    double pitchRad = pitch! * (pi / 180.0);
    
    // Tilt compensation
    double mx = magX! * cos(pitchRad) + magZ! * sin(pitchRad);
    double my = magX! * sin(rollRad) * sin(pitchRad) + 
               magY! * cos(rollRad) - 
               magZ! * sin(rollRad) * cos(pitchRad);
    
    // Calculate yaw
    double yaw = atan2(-my, mx) * (180.0 / pi);
    return _normalizeAngleDeg(yaw);
  }
  
  /// Update orientation based on current sensor values
  void _updateOrientation() {
    if (roll == null || pitch == null) {
      // Initialize with accelerometer data
      roll = _calculateAccelerometerRoll();
      pitch = _calculateAccelerometerPitch();
      yaw = 0.0;
    }
    
    // Apply offsets
    roll = roll! - _rollOffsetDeg;
    pitch = pitch! - _pitchOffsetDeg;
    yaw = _normalizeAngleDeg((yaw ?? 0.0) - _yawOffsetDeg);
    
    // Notify listeners
    _controller.add([
      roll! * (pi / 180.0),
      pitch! * (pi / 180.0),
      (yaw ?? 0.0) * (pi / 180.0),
    ]);
  }

  double _normalizeAngleDeg(double a) {
    double x = a;
    while (x > 180.0) x -= 360.0;
    while (x <= -180.0) x += 360.0;
    return x;
  }

  /// Clean up resources
  void dispose() {
    stop();
    _controller.close();
  }
}
