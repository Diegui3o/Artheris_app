import 'dart:typed_data';
import 'kalman_service.dart';
import 'gyro_service.dart';

class AngleFilterService {
  // Kalman filters for roll and pitch
  late final KalmanFilter _kalmanRoll;
  late final KalmanFilter _kalmanPitch;
  
  // Time step in seconds (0.006s = 6ms)
  final double _dt = 0.006;
  
  // Gyro service instance
  final GyroService _gyroService = GyroService();
  
  // Current filtered angles in degrees
  double roll = 0.0;
  double pitch = 0.0;
  
  AngleFilterService() {
    // Initialize Kalman filters with default parameters
    _kalmanRoll = KalmanFilter(
      qAngleInit: 0.001,
      qBiasInit: 0.003,
      rMeasureInit: 0.03,
    );
    
    _kalmanPitch = KalmanFilter(
      qAngleInit: 0.001,
      qBiasInit: 0.003,
      rMeasureInit: 0.03,
    );
  }
  
  // Update the filter with new gyro data
  void updateFromGyro(int rawX, int rawY, int rawZ) {
    // Update gyro service with raw data
    _gyroService.updateFromRawInts(rawX, rawY, rawZ);
    
    // Update Kalman filters with gyro rates and time step
    roll = _kalmanRoll.update(roll, _gyroService.gyroRateRoll, _dt);
    pitch = _kalmanPitch.update(pitch, _gyroService.gyroRatePitch, _dt);
  }
  
  // Alternative update method using raw bytes
  void updateFromGyroBytes(Uint8List bytes) {
    _gyroService.updateFromRawBytes(bytes);
    
    // Update Kalman filters with gyro rates and time step
    roll = _kalmanRoll.update(roll, _gyroService.gyroRateRoll, _dt);
    pitch = _kalmanPitch.update(pitch, _gyroService.gyroRatePitch, _dt);
  }
  
  // Reset the filter
  void reset() {
    _kalmanRoll.reset();
    _kalmanPitch.reset();
    roll = 0.0;
    pitch = 0.0;
  }
}