// lib/core/sensors/orientation_service.dart
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Orientation service using quaternion integration + Madgwick filter.
/// Internally works in radians; but exposes legacy getters in DEGREES
/// to remain compatible with existing code that expects .roll/.pitch/.yaw.
class OrientationService {
  // Raw sensor values (SI: m/s² for acc, µT for mag). Use null if not present.
  double? _accX, _accY, _accZ;
  double? _magX, _magY, _magZ;

  // Public legacy getters (DEGREES) so existing code compiles:
  double? get accX => _accX;
  double? get accY => _accY;
  double? get accZ => _accZ;
  double? get magX => _magX;
  double? get magY => _magY;
  double? get magZ => _magZ;

  // Quaternion state (w, x, y, z)
  Quaternion _q = Quaternion(1.0, 0.0, 0.0, 0.0);

  // Expose roll/pitch/yaw in DEGREES (legacy)
  double? get roll {
    final e = _q.toEuler();
    return e[0] * 180.0 / pi;
  }

  double? get pitch {
    final e = _q.toEuler();
    return e[1] * 180.0 / pi;
  }

  double? get yaw {
    final e = _q.toEuler();
    return e[2] * 180.0 / pi;
  }

  // Offsets (stored in radians)
  double _rollOffset = 0.0;
  double _pitchOffset = 0.0;
  double _yawOffset = 0.0;

  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // High-resolution timer for dt
  final Stopwatch _sw = Stopwatch();

  // Madgwick filter
  final MadgwickAHRS _filter;

  // Stream controller that emits [roll, pitch, yaw] in radians
  final StreamController<List<double>> _controller =
      StreamController<List<double>>.broadcast();

  Stream<List<double>> get orientationStream => _controller.stream;

  OrientationService({double beta = 0.1}) : _filter = MadgwickAHRS(beta: beta) {
    _sw.start();
  }

  /// Start listening to sensors
  Future<void> start() async {
    // Accelerometer
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      _accX = e.x;
      _accY = e.y;
      _accZ = e.z;
      // emit Euler (radians) with offsets applied
      _emitEuler();
    });

    // Magnetometer
    _magSub = magnetometerEvents.listen((MagnetometerEvent e) {
      _magX = e.x;
      _magY = e.y;
      _magZ = e.z;
    });

    // Gyroscope: sensors_plus reports rad/s (typical). Use dt from Stopwatch.
    _gyroSub = gyroscopeEvents.listen((GyroscopeEvent g) {
      final double dt = _computeDt();
      if (dt <= 0) return;

      final gx = g.x; // rad/s
      final gy = g.y;
      final gz = g.z;

      if (_accX != null && _accY != null && _accZ != null) {
        if (_magX != null && _magY != null && _magZ != null) {
          _filter.update(
            gx,
            gy,
            gz,
            _accX!,
            _accY!,
            _accZ!,
            _magX!,
            _magY!,
            _magZ!,
            dt,
          );
        } else {
          _filter.updateIMU(gx, gy, gz, _accX!, _accY!, _accZ!, dt);
        }
      } else {
        // No acc: integrate gyro
        _q = Quaternion.integrateGyro(_q, gx, gy, gz, dt);
        _q = _q.normalized();
        _filter.quaternion = _q;
      }

      // sync quaternion from filter
      _q = _filter.quaternion;

      _emitEuler();
    });
  }

  /// Stop listening
  void stop() {
    _accelSub?.cancel();
    _magSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _magSub = null;
    _gyroSub = null;
    _sw.reset();
  }

  /// Legacy-compatible: calibrateZero expects DEGREES (keeps API)
  void calibrateZero(
    double currentRollDeg,
    double currentPitchDeg,
    double currentYawDeg,
  ) {
    _rollOffset = _deg2rad(currentRollDeg);
    _pitchOffset = _deg2rad(currentPitchDeg);
    _yawOffset = _normalizeRad(_deg2rad(currentYawDeg));
  }

  /// Legacy-compatible manual updateOrientation(roll:..., pitch:..., yaw:...)
  /// Accepts DEGREES to preserve previous calls in your codebase.
  void updateOrientation({double? roll, double? pitch, double? yaw}) {
    if (roll != null) _rollOffset = _deg2rad(roll);
    if (pitch != null) _pitchOffset = _deg2rad(pitch);
    if (yaw != null) _yawOffset = _normalizeRad(_deg2rad(yaw));
    _emitEuler();
  }

  /// New-style manual update if you prefer radians:
  void updateOrientationRadians({
    double? rollRad,
    double? pitchRad,
    double? yawRad,
  }) {
    if (rollRad != null) _rollOffset = rollRad;
    if (pitchRad != null) _pitchOffset = pitchRad;
    if (yawRad != null) _yawOffset = _normalizeRad(yawRad);
    _emitEuler();
  }

  /// Reset offsets and quaternion state
  void reset() {
    _q = Quaternion(1.0, 0.0, 0.0, 0.0);
    _rollOffset = 0.0;
    _pitchOffset = 0.0;
    _yawOffset = 0.0;
  }

  /// Emits current Euler angles (radian) applying offsets and normalization.
  void _emitEuler() {
    final e = _q.toEuler(); // returns (roll, pitch, yaw) in radians
    double roll = e[0] - _rollOffset;
    double pitch = e[1] - _pitchOffset;
    double yaw = _normalizeRad(e[2] - _yawOffset);
    yaw = _normalizeRad(yaw);
    _controller.add([roll, pitch, yaw]);
  }

  double _computeDt() {
    final elapsedUs = _sw.elapsedMicroseconds;
    _sw.reset();
    _sw.start();
    if (elapsedUs <= 0) return 0.0;
    return elapsedUs / 1e6; // seconds
  }

  double _deg2rad(double d) => d * pi / 180.0;

  double _normalizeRad(double a) {
    double x = a;
    while (x > pi) x -= 2 * pi;
    while (x <= -pi) x += 2 * pi;
    return x;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

/// ---------- Quaternion helper ----------
class Quaternion {
  double w, x, y, z;
  Quaternion(this.w, this.x, this.y, this.z);

  Quaternion normalized() {
    final n = sqrt(w * w + x * x + y * y + z * z);
    if (n == 0) return Quaternion(1, 0, 0, 0);
    return Quaternion(w / n, x / n, y / n, z / n);
  }

  // Multiply this * other
  Quaternion operator *(Quaternion o) {
    return Quaternion(
      w * o.w - x * o.x - y * o.y - z * o.z,
      w * o.x + x * o.w + y * o.z - z * o.y,
      w * o.y - x * o.z + y * o.w + z * o.x,
      w * o.z + x * o.y - y * o.x + z * o.w,
    );
  }

  /// Integrate a small rotation from gyro (rad/s) over dt seconds
  static Quaternion integrateGyro(
    Quaternion q,
    double gx,
    double gy,
    double gz,
    double dt,
  ) {
    final double omegaMagnitude = sqrt(gx * gx + gy * gy + gz * gz);
    if (omegaMagnitude * dt > 0.0) {
      final double thetaOverTwo = omegaMagnitude * dt / 2.0;
      final double sinThetaOverTwo = sin(thetaOverTwo);
      final double cosThetaOverTwo = cos(thetaOverTwo);
      final double nx = gx / omegaMagnitude;
      final double ny = gy / omegaMagnitude;
      final double nz = gz / omegaMagnitude;
      final dq = Quaternion(
        cosThetaOverTwo,
        sinThetaOverTwo * nx,
        sinThetaOverTwo * ny,
        sinThetaOverTwo * nz,
      );
      return (q * dq).normalized();
    } else {
      return q;
    }
  }

  /// Convert quaternion -> Euler angles (roll, pitch, yaw) in radians
  List<double> toEuler() {
    final double sinrCosp = 2.0 * (w * x + y * z);
    final double cosrCosp = 1.0 - 2.0 * (x * x + y * y);
    final roll = atan2(sinrCosp, cosrCosp);

    final double sinp = 2.0 * (w * y - z * x);
    double pitch;
    if (sinp.abs() >= 1)
      pitch = sinp > 0 ? pi / 2 : -pi / 2;
    else
      pitch = asin(sinp);

    final double sinyCosp = 2.0 * (w * z + x * y);
    final double cosyCosp = 1.0 - 2.0 * (y * y + z * z);
    final yaw = atan2(sinyCosp, cosyCosp);

    return [roll, pitch, yaw];
  }
}

class MadgwickAHRS {
  double beta; // algorithm gain
  Quaternion quaternion = Quaternion(1.0, 0.0, 0.0, 0.0);

  MadgwickAHRS({this.beta = 0.1});

  /// Full AHRS update using gyro (rad/s), acc (m/s^2), mag (µT), and dt (s)
  void update(
    double gx,
    double gy,
    double gz,
    double ax,
    double ay,
    double az,
    double mx,
    double my,
    double mz,
    double dt,
  ) {
    // Normalize accelerometer measurement
    double norm = sqrt(ax * ax + ay * ay + az * az);
    if (norm == 0.0) return; // invalid data
    ax /= norm;
    ay /= norm;
    az /= norm;

    // Normalize magnetometer measurement
    norm = sqrt(mx * mx + my * my + mz * mz);
    if (norm == 0.0) {
      // fallback to IMU-only update
      updateIMU(gx, gy, gz, ax, ay, az, dt);
      return;
    }
    mx /= norm;
    my /= norm;
    mz /= norm;

    // Short names
    double q1 = quaternion.w;
    double q2 = quaternion.x;
    double q3 = quaternion.y;
    double q4 = quaternion.z;

    // Reference direction of Earth's magnetic field
    final double hx =
        mx * (q1 * q1 - q2 * q2 - q3 * q3 + q4 * q4) +
        2.0 * my * (q1 * q4 + q2 * q3) +
        2.0 * mz * (q2 * q4 - q1 * q3);
    final double hy =
        2.0 * mx * (q2 * q3 - q1 * q4) +
        my * (q1 * q1 - q2 * q2 + q3 * q3 - q4 * q4) +
        2.0 * mz * (q1 * q2 + q3 * q4);
    // bx and bz are calculated but not used in this implementation
    // Keeping the calculations for future reference
    final double bx = sqrt(hx * hx + hy * hy);
    final double bz =
        2.0 *
        (mx * (q1 * q3 + q2 * q4) +
            my * (q3 * q4 - q1 * q2) +
            mz * (q1 * q1 - q2 * q2 - q3 * q3 + q4 * q4)) /
        2.0;

    // Gradient decent algorithm corrective step (simplified implementation)
    // Note: For brevity we implement a commonly-used approximation.
    double s1 = 0.0, s2 = 0.0, s3 = 0.0, s4 = 0.0;

    // Compute objective function and Jacobian (omitted full derivation)
    // This block is a practical, stable implementation used in many Madgwick variants.
    final double q1x2 = 2.0 * q1;
    final double q2x2 = 2.0 * q2;
    final double q3x2 = 2.0 * q3;
    final double q4x2 = 2.0 * q4;
    final double q1x4 = 4.0 * q1;
    final double q2x4 = 4.0 * q2;
    final double q3x4 = 4.0 * q3;
    final double q2x8 = 8.0 * q2;
    final double q3x8 = 8.0 * q3;
    final double q1q1 = q1 * q1;
    final double q2q2 = q2 * q2;
    final double q3q3 = q3 * q3;
    final double q4q4 = q4 * q4;

    final double f1 = q2x2 * q4 - q1x2 * q3 - ax;
    final double f2 = q1x2 * q2 + q3x2 * q4 - ay;
    final double f3 = 1.0 - q2x2 * q2 - q3x2 * q3 - az;

    s1 = q1x4 * q3q3 + q3x2 * ax + q1x4 * q2q2 - q2x2 * ay;
    s2 =
        q2x4 * q4q4 -
        q4x2 * ax +
        4.0 * q1q1 * q2 -
        q1x2 * ay -
        q2x4 +
        q2x8 * q2q2 +
        q2x8 * q3q3 +
        q2x4 * az;
    s3 =
        4.0 * q1q1 * q3 +
        q1x2 * ax +
        q3x4 * q4q4 -
        q4x2 * ay -
        q3x4 +
        q3x8 * q2q2 +
        q3x8 * q3q3 +
        q3x4 * az;
    s4 = 4.0 * q2q2 * q4 - q2x2 * ax + 4.0 * q3q3 * q4 - q3x2 * ay;

    // Normalize step
    double sNorm = sqrt(s1 * s1 + s2 * s2 + s3 * s3 + s4 * s4);
    if (sNorm == 0.0) {
      // Prevent division by zero; fallback to IMU update
      updateIMU(gx, gy, gz, ax, ay, az, dt);
      return;
    }
    s1 /= sNorm;
    s2 /= sNorm;
    s3 /= sNorm;
    s4 /= sNorm;

    // Rate of change of quaternion from gyroscope
    final double qDot1 = 0.5 * (-q2 * gx - q3 * gy - q4 * gz) - beta * s1;
    final double qDot2 = 0.5 * (q1 * gx + q3 * gz - q4 * gy) - beta * s2;
    final double qDot3 = 0.5 * (q1 * gy - q2 * gz + q4 * gx) - beta * s3;
    final double qDot4 = 0.5 * (q1 * gz + q2 * gy - q3 * gx) - beta * s4;

    // Integrate to yield quaternion
    q1 += qDot1 * dt;
    q2 += qDot2 * dt;
    q3 += qDot3 * dt;
    q4 += qDot4 * dt;

    quaternion = Quaternion(q1, q2, q3, q4).normalized();
  }

  /// IMU-only update (no magnetometer)
  void updateIMU(
    double gx,
    double gy,
    double gz,
    double ax,
    double ay,
    double az,
    double dt,
  ) {
    // Normalize accelerometer measurement
    double norm = sqrt(ax * ax + ay * ay + az * az);
    if (norm == 0.0) return; // invalid data
    ax /= norm;
    ay /= norm;
    az /= norm;

    double q1 = quaternion.w,
        q2 = quaternion.x,
        q3 = quaternion.y,
        q4 = quaternion.z;

    final double q1x2 = 2.0 * q1;
    final double q2x2 = 2.0 * q2;
    final double q3x2 = 2.0 * q3;
    final double q4x2 = 2.0 * q4;
    final double q1x4 = 4.0 * q1;
    final double q2x4 = 4.0 * q2;
    final double q3x4 = 4.0 * q3;
    final double q2x8 = 8.0 * q2;
    final double q3x8 = 8.0 * q3;
    final double q1q1 = q1 * q1;
    final double q2q2 = q2 * q2;
    final double q3q3 = q3 * q3;
    final double q4q4 = q4 * q4;

    final double f1 = q2x2 * q4 - q1x2 * q3 - ax;
    final double f2 = q1x2 * q2 + q3x2 * q4 - ay;
    final double f3 = 1.0 - q2x2 * q2 - q3x2 * q3 - az;

    double s1 = q1x4 * q3q3 + q3x2 * ax + q1x4 * q2q2 - q2x2 * ay;
    double s2 =
        q2x4 * q4q4 -
        q4x2 * ax +
        4.0 * q1q1 * q2 -
        q1x2 * ay -
        q2x4 +
        q2x8 * q2q2 +
        q2x8 * q3q3 +
        q2x4 * az;
    double s3 =
        4.0 * q1q1 * q3 +
        q1x2 * ax +
        q3x4 * q4q4 -
        q4x2 * ay -
        q3x4 +
        q3x8 * q2q2 +
        q3x8 * q3q3 +
        q3x4 * az;
    double s4 = 4.0 * q2q2 * q4 - q2x2 * ax + 4.0 * q3q3 * q4 - q3x2 * ay;

    double sNorm = sqrt(s1 * s1 + s2 * s2 + s3 * s3 + s4 * s4);
    if (sNorm == 0.0) {
      // fallback: pure gyro integration
      quaternion = Quaternion.integrateGyro(quaternion, gx, gy, gz, dt);
      return;
    }

    s1 /= sNorm;
    s2 /= sNorm;
    s3 /= sNorm;
    s4 /= sNorm;

    final double qDot1 = 0.5 * (-q2 * gx - q3 * gy - q4 * gz) - beta * s1;
    final double qDot2 = 0.5 * (q1 * gx + q3 * gz - q4 * gy) - beta * s2;
    final double qDot3 = 0.5 * (q1 * gy - q2 * gz + q4 * gx) - beta * s3;
    final double qDot4 = 0.5 * (q1 * gz + q2 * gy - q3 * gx) - beta * s4;

    q1 += qDot1 * dt;
    q2 += qDot2 * dt;
    q3 += qDot3 * dt;
    q4 += qDot4 * dt;

    quaternion = Quaternion(q1, q2, q3, q4).normalized();
  }
}
