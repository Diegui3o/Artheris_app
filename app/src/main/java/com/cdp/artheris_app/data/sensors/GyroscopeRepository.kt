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

data class GyroscopeReading(
    val degPerSecX: Float,
    val degPerSecY: Float,
    val degPerSecZ: Float,
    val mpuRawX: Int,
    val mpuRawY: Int,
    val mpuRawZ: Int,
    val timestamp: Long
)

class GyroscopeRepository(context: Context) {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val gyroSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

    fun gyroscopeFlow(samplePeriodUs: Int = SensorManager.SENSOR_DELAY_GAME): Flow<GyroscopeReading> = callbackFlow {
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (event.sensor.type != Sensor.TYPE_GYROSCOPE) return
                val now = System.currentTimeMillis()
                // event.values are in rad/s
                val rx = event.values.getOrNull(0) ?: 0f
                val ry = event.values.getOrNull(1) ?: 0f
                val rz = event.values.getOrNull(2) ?: 0f

                val degX = rx * (180f / PI.toFloat())
                val degY = ry * (180f / PI.toFloat())
                val degZ = rz * (180f / PI.toFloat())

                // Convertir a "raw MPU" aproximado (lo que leerías con Wire.read antes del /65.5)
                val rawXf = degX * sensitivityLsbPerDps
                val rawYf = degY * sensitivityLsbPerDps
                val rawZf = degZ * sensitivityLsbPerDps

                // Clamp a int16_t range y convertir a Int
                val rawX = clampToInt16(rawXf)
                val rawY = clampToInt16(rawYf)
                val rawZ = clampToInt16(rawZf)

                trySend(GyroscopeReading(degX, degY, degZ, now))
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
}
