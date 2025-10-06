import 'dart:math';
import 'dart:typed_data';

class GyroService {
  // Sensibilidad del MPU6050 a ±500 °/s
  static const double _sensitivity = 65.5;

  double gyroRateRoll = 0.0; // X → Roll
  double gyroRatePitch = 0.0; // Y → Pitch
  double rateYaw = 0.0; // Z → Yaw

  void updateFromRawInts(int rawX, int rawY, int rawZ) {
    // Convierte a signed 16-bit si llegan como positivos grandes
    if (rawX & 0x8000 != 0) rawX -= 0x10000;
    if (rawY & 0x8000 != 0) rawY -= 0x10000;
    if (rawZ & 0x8000 != 0) rawZ -= 0x10000;

    gyroRateRoll = rawX / _sensitivity; // °/s
    gyroRatePitch = rawY / _sensitivity; // °/s
    rateYaw = rawZ / _sensitivity; // °/s
  }

  /// Si recibes los bytes del sensor (6 bytes: XH XL YH YL ZH ZL)
  void updateFromRawBytes(Uint8List bytes) {
    if (bytes.length < 6) return;
    int rawX = (bytes[0] << 8) | bytes[1];
    int rawY = (bytes[2] << 8) | bytes[3];
    int rawZ = (bytes[4] << 8) | bytes[5];
    updateFromRawInts(rawX, rawY, rawZ);
  }

  /// Si quieres los valores en rad/s (opcional)
  double get gyroRoll_rad => gyroRateRoll * pi / 180.0;
  double get gyroPitch_rad => gyroRatePitch * pi / 180.0;
  double get gyroYaw_rad => rateYaw * pi / 180.0;
}
