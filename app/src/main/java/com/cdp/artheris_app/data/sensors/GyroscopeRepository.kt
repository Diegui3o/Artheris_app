package com.cdp.artheris_app.data.sensors

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlin.math.PI
import kotlin.math.roundToInt

data class GyroscopeReading(
    val degPerSecX: Float,   // grados/segundo (convertido desde rad/s)
    val degPerSecY: Float,
    val degPerSecZ: Float,
    val mpuRawX: Int,        // raw equivalente (int16) similar a Wire.read <<8 | Wire.read()
    val mpuRawY: Int,
    val mpuRawZ: Int,
    val timestamp: Long
)

class GyroscopeRepository(
    context: Context,
    private val sensitivityLsbPerDps: Float = 65.5f // LSB/(°/s) — MPU típico ±500°/s
) {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val gyroSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

    fun gyroscopeFlow(samplePeriodUs: Int = SensorManager.SENSOR_DELAY_GAME): Flow<GyroscopeReading> = callbackFlow {
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (event.sensor.type != Sensor.TYPE_GYROSCOPE) return
                val now = System.currentTimeMillis()

                // Android entrega rad/s
                val rx = event.values.getOrNull(0) ?: 0f
                val ry = event.values.getOrNull(1) ?: 0f
                val rz = event.values.getOrNull(2) ?: 0f

                // 1) convertir rad/s -> deg/s
                val degX = rx * (180f / PI.toFloat())
                val degY = ry * (180f / PI.toFloat())
                val degZ = rz * (180f / PI.toFloat())

                // 2) calcular raw equivalente MPU (antes del /65.5)
                val rawXf = degX * sensitivityLsbPerDps
                val rawYf = degY * sensitivityLsbPerDps
                val rawZf = degZ * sensitivityLsbPerDps

                // 3) clamp a rango int16 para simular int16_t GyroX
                val rawX = clampToInt16(rawXf)
                val rawY = clampToInt16(rawYf)
                val rawZ = clampToInt16(rawZf)

                trySend(
                    GyroscopeReading(
                        degPerSecX = degX,
                        degPerSecY = degY,
                        degPerSecZ = degZ,
                        mpuRawX = rawX,
                        mpuRawY = rawY,
                        mpuRawZ = rawZ,
                        timestamp = now
                    )
                )
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) { /* no-op */ }
        }

        gyroSensor?.let {
            sensorManager.registerListener(listener, it, samplePeriodUs)
        } ?: run {
            close(IllegalStateException("No se encontró giroscopio en este dispositivo"))
        }

        awaitClose { sensorManager.unregisterListener(listener) }
    }

    private fun clampToInt16(v: Float): Int {
        val r = v.roundToInt()
        return when {
            r > Short.MAX_VALUE -> Short.MAX_VALUE.toInt()
            r < Short.MIN_VALUE -> Short.MIN_VALUE.toInt()
            else -> r
        }
    }
}
