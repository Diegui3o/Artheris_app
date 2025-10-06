import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

class GyroService {
  // Stream controller for gyro updates
  final StreamController<void> _updateController = StreamController<void>.broadcast();
  StreamSubscription<dynamic>? _sensorSubscription;
  // Sensibilidad del MPU6050 a ±500 °/s
  static const double _sensitivity = 65.5;

  // Raw gyro rates in degrees per second
  double gyroRateRoll = 0.0; // X → Roll
  double gyroRatePitch = 0.0; // Y → Pitch
  double rateYaw = 0.0; // Z → Yaw
  
  // Public getters with consistent naming
  double? get rollRate => gyroRateRoll;
  double? get pitchRate => gyroRatePitch;
  double? get yawRate => rateYaw;
  
  // Stream of gyro updates
  Stream<void> get onUpdate => _updateController.stream;

  /// Start listening to gyroscope updates (if using platform channels or sensors_plus)
  void start() {
    // This is a placeholder - implement actual sensor subscription if needed
    // Example with sensors_plus:
    // _sensorSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
    //   updateFromRawInts(
    //     (event.x * 1000).toInt(),
    //     (event.y * 1000).toInt(),
    //     (event.z * 1000).toInt(),
    //   );
    // });
  }
  
  /// Stop listening to gyroscope updates
  void stop() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
  }
  
  /// Reset all gyro rates to zero
  void reset() {
    gyroRateRoll = 0.0;
    gyroRatePitch = 0.0;
    rateYaw = 0.0;
    _updateController.add(null);
  }
  
  /// Update gyro rates from raw sensor values
  void updateFromRawInts(int rawX, int rawY, int rawZ) {
    // Convierte a signed 16-bit si llegan como positivos grandes
    if (rawX & 0x8000 != 0) rawX -= 0x10000;
    if (rawY & 0x8000 != 0) rawY -= 0x10000;
    if (rawZ & 0x8000 != 0) rawZ -= 0x10000;

    gyroRateRoll = rawX / _sensitivity; // °/s
    gyroRatePitch = rawY / _sensitivity; // °/s
    rateYaw = rawZ / _sensitivity; // °/s
    
    // Notify listeners of the update
    _updateController.add(null);
  }

  /// Si recibes los bytes del sensor (6 bytes: XH XL YH YL ZH ZL)
  void updateFromRawBytes(Uint8List bytes) {
    if (bytes.length < 6) return;
    int rawX = (bytes[0] << 8) | bytes[1];
    int rawY = (bytes[2] << 8) | bytes[3];
    int rawZ = (bytes[4] << 8) | bytes[5];
    updateFromRawInts(rawX, rawY, rawZ);
  }

  /// Get gyro rates in rad/s (convenience methods)
  double get gyroRoll_rad => gyroRateRoll * pi / 180.0;
  double get gyroPitch_rad => gyroRatePitch * pi / 180.0;
  double get gyroYaw_rad => rateYaw * pi / 180.0;
  
  /// Clean up resources
  void dispose() {
    stop();
    _updateController.close();
  }
}
