package com.cdp.artheris_app.data.sensors

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow

data class AccelerometerReading(
    val x: Float,      // m/s^2
    val y: Float,
    val z: Float,
    val timestamp: Long
)

class AccelerometerRepository(context: Context) {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val accelerometer: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

    fun accelerometerFlow(samplePeriodUs: Int = SensorManager.SENSOR_DELAY_UI): Flow<AccelerometerReading> = callbackFlow {
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
                val now = System.currentTimeMillis()
                val x = event.values.getOrNull(0) ?: 0f
                val y = event.values.getOrNull(1) ?: 0f
                val z = event.values.getOrNull(2) ?: 0f
                trySend(AccelerometerReading(x, y, z, now))
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) { /* no-op */ }
        }

        accelerometer?.let {
            sensorManager.registerListener(listener, it, samplePeriodUs)
        } ?: run {
            close(IllegalStateException("No se encontró acelerómetro en este dispositivo"))
        }

        awaitClose { sensorManager.unregisterListener(listener) }
    }
}
