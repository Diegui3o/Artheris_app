package com.cdp.artheris_app.data.sensors

/**
 * Implementación del filtro de Kalman para un único ángulo (roll o pitch).
 * Traducción del algoritmo que proporcionaste en C++.
 */
class KalmanFilter(
    var Q_angle: Double = 0.001,   // covarianza proceso (ángulo)
    var Q_bias: Double = 0.003,    // covarianza proceso (bias)
    var R_measure: Double = 0.03   // covarianza medición (acel)
) {
    var angle: Double = 0.0   // ángulo estimado
    var bias: Double = 0.0    // bias del giroscopio
    private val P = Array(2) { DoubleArray(2) { 0.0 } } // matriz de covarianza 2x2

    /**
     * Actualiza el filtro con una nueva medición.
     * @param newAngle: ángulo medido (por ejemplo del acelerómetro) en grados
     * @param newRate: tasa del giroscopio (deg/s)
     * @param dt: intervalo de tiempo en segundos
     * @return ángulo filtrado (degrees)
     */
    fun update(newAngle: Double, newRate: Double, dt: Double): Double {
        // Predicción
        val rate = newRate - bias
        angle += dt * rate

        // Actualizar matriz de covarianza P
        P[0][0] += dt * (dt * P[1][1] - P[0][1] - P[1][0] + Q_angle)
        P[0][1] -= dt * P[1][1]
        P[1][0] -= dt * P[1][1]
        P[1][1] += Q_bias * dt

        // Medición
        val S = P[0][0] + R_measure
        val K0 = P[0][0] / S
        val K1 = P[1][0] / S

        // Actualización con la medición
        val y = newAngle - angle
        angle += K0 * y
        bias += K1 * y

        // Actualizar P
        val P00_temp = P[0][0]
        val P01_temp = P[0][1]

        P[0][0] -= K0 * P00_temp
        P[0][1] -= K0 * P01_temp
        P[1][0] -= K1 * P00_temp
        P[1][1] -= K1 * P01_temp

        return angle
    }

    /** Reinicia el filtro (útil si requieres reset) */
    fun reset(initialAngle: Double = 0.0, initialBias: Double = 0.0) {
        angle = initialAngle
        bias = initialBias
        P[0][0] = 1.0
        P[0][1] = 0.0
        P[1][0] = 0.0
        P[1][1] = 1.0
    }
}
