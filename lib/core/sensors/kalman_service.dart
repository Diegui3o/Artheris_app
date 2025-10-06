class KalmanFilter {
  // Tuning parameters (puedes exponerlos al constructor)
  double qAngle = 0.001; // process noise angle
  double qBias = 0.003; // process noise bias
  double rMeasure = 0.03; // measurement noise

  double angle = 0.0; // estimated angle (deg)
  double bias = 0.0; // estimated gyro bias (deg/s)

  List<List<double>> p = [
    [0.0, 0.0],
    [0.0, 0.0],
  ];

  KalmanFilter({double? qAngleInit, double? qBiasInit, double? rMeasureInit}) {
    if (qAngleInit != null) qAngle = qAngleInit;
    if (qBiasInit != null) qBias = qBiasInit;
    if (rMeasureInit != null) rMeasure = rMeasureInit;
    // Valores iniciales para P (pequeño valor si confiamos en inicio)
    p[0][0] = 0.01;
    p[0][1] = 0.0;
    p[1][0] = 0.0;
    p[1][1] = 0.01;
  }

  // Normaliza la diferencia de ángulos a [-180, 180]
  double _angDiff(double a) {
    double x = a;
    while (x > 180.0) {
      x -= 360.0;
    }
    while (x < -180.0) {
      x += 360.0;
    }
    return x;
  }

  // Ahora recibe dt en segundos
  double update(double newAngleDeg, double newRateDegPerSec, double dt) {
    // Prediction
    double rate = newRateDegPerSec - bias;
    angle += dt * rate;

    // Update P
    p[0][0] += dt * (dt * p[1][1] - p[0][1] - p[1][0] + qAngle);
    p[0][1] -= dt * p[1][1];
    p[1][0] -= dt * p[1][1];
    p[1][1] += qBias * dt;

    // Measurement update
    double s = p[0][0] + rMeasure;
    double k0 = p[0][0] / s;
    double k1 = p[1][0] / s;

    // Normalizar la diferencia de ángulo
    double y = _angDiff(newAngleDeg - angle);

    angle += k0 * y;
    bias += k1 * y;

    // Update covariance
    double p00Temp = p[0][0];
    double p01Temp = p[0][1];

    p[0][0] -= k0 * p00Temp;
    p[0][1] -= k0 * p01Temp;
    p[1][0] -= k1 * p00Temp;
    p[1][1] -= k1 * p01Temp;

    return angle;
  }

  void reset({double pInit = 0.01}) {
    angle = 0.0;
    bias = 0.0;
    p[0][0] = pInit;
    p[0][1] = 0.0;
    p[1][0] = 0.0;
    p[1][1] = pInit;
  }
}
