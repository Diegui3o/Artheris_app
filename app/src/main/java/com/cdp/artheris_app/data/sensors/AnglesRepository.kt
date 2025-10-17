package com.cdp.artheris_app.data.sensors

import android.content.Context
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlin.math.atan2
import kotlin.math.sqrt
import kotlin.math.PI

data class AnglesReading(
    val roll_est: Float,   // grados
    val pitch_est: Float,  // grados
    val timestamp: Long
)

class AnglesRepository(
    context: Context,
    private val accelRepository: AccelerometerRepository = AccelerometerRepository(context)
) {
    /**
     * Flujo de ángulos estimados (Roll y Pitch) calculados desde el acelerómetro.
     * Usa las fórmulas:
     * roll  = atan2(AccY, sqrt(AccX^2 + AccZ^2)) * 180 / PI
     * pitch = -atan2(AccX, sqrt(AccY^2 + AccZ^2)) * 180 / PI
     */
    fun anglesFlow(): Flow<AnglesReading> {
        return accelRepository.accelerometerFlow().map { acc ->
            val roll_est = Math.toDegrees(
                atan2(
                    acc.y.toDouble(),
                    sqrt(acc.x * acc.x + acc.z * acc.z).toDouble()
                )
            ).toFloat()
            val pitch_est = -Math.toDegrees(
                atan2(
                    acc.x.toDouble(),
                    sqrt(acc.y * acc.y + acc.z * acc.z).toDouble()
                )
            ).toFloat()
            AnglesReading(
                roll_est = roll_est,
                pitch_est = pitch_est,
                timestamp = acc.timestamp
            )
        }
    }
}