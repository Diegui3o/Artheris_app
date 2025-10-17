package com.cdp.artheris_app.data.sensors

import android.content.Context
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlin.math.max

data class AnglesFilteredReading(
    val roll: Float,
    val pitch: Float,
    val timestamp: Long
)
/**
 * KalmanRepository combina:
 * - anglesFlow() (estimaciones por acelerómetro -> AnglesReading)
 * - gyroscopeFlow() (tasas en deg/s -> GyroscopeReading)
 *
 * Y aplica dos filtros Kalman (uno para roll y otro para pitch).
 */
class KalmanRepository(
    context: Context,
    private val anglesRepository: AnglesRepository = AnglesRepository(context),
    private val gyroRepository: GyroscopeRepository = GyroscopeRepository(context),
    // parámetros del filtro (puedes cambiarlos si deseas)
    private val Q_angle: Double = 0.001,
    private val Q_bias: Double = 0.003,
    private val R_measure: Double = 0.03
) {

    private val kfRoll = KalmanFilter(Q_angle = Q_angle, Q_bias = Q_bias, R_measure = R_measure)
    private val kfPitch = KalmanFilter(Q_angle = Q_angle, Q_bias = Q_bias, R_measure = R_measure)
    private var lastTimestamp: Long? = null

    /**
     * Devuelve un Flow<AnglesFilteredReading>.
     * Combina el flujo de ángulos estimados por accelerómetro y el flujo del giroscopio.
     * Nota: utiliza timestamps en ms y calcula dt en segundos.
     */
    fun filteredAnglesFlow(): Flow<AnglesFilteredReading> {
        val anglesFlow = anglesRepository.anglesFlow()
        val gyroFlow = gyroRepository.gyroscopeFlow()

        return anglesFlow.combine(gyroFlow) { angles, gyro ->
            // Calcula dt usando el timestamp más reciente disponible
            val nowTs = max(angles.timestamp, gyro.timestamp)
            val dtSec: Double = if (lastTimestamp == null) {
                // primer ciclo, usa 0.01s por defecto
                0.01
            } else {
                val dtMs = (nowTs - (lastTimestamp ?: nowTs)).coerceAtLeast(1L)
                dtMs.toDouble() / 1000.0
            }
            lastTimestamp = nowTs

            // newAngle (acel estimator) y newRate (gyro) - asumimos:
            // - roll: usar gyro.degPerSecX
            // - pitch: usar gyro.degPerSecY
            // Ajusta si tu orientación de ejes es distinta.
            val rollMeasured = angles.roll_est.toDouble()
            val pitchMeasured = angles.pitch_est.toDouble()

            val rollRate = gyro.degPerSecX.toDouble()
            val pitchRate = gyro.degPerSecY.toDouble()

            val rollFiltered = kfRoll.update(rollMeasured, rollRate, dtSec)
            val pitchFiltered = kfPitch.update(pitchMeasured, pitchRate, dtSec)

            AnglesFilteredReading(
                roll = rollFiltered.toFloat(),
                pitch = pitchFiltered.toFloat(),
                timestamp = nowTs
            )
        }.map { it } // simplemente propagamos el objeto resultante
    }
}
