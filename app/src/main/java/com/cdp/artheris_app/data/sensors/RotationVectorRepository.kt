package com.cdp.artheris_app.data.sensors

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlin.math.abs

data class OrientationReading(
    val yaw: Float,    // ya calibrado (con offset) en –180..180
    val pitch: Float,
    val roll: Float,
    val timestamp: Long
)

class RotationVectorRepository(context: Context) {

    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotationVectorSensor: Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

    // === Persistencia simple del offset ===
    private val prefs = context.getSharedPreferences("orientation_prefs", Context.MODE_PRIVATE)
    @Volatile private var yawOffsetDeg: Float =
        prefs.getFloat("yaw_offset_deg", 0f)

    // Último yaw bruto (–180..180) para calibrar respecto al valor más reciente
    @Volatile private var lastYawRawDeg: Float = 0f

    fun getOrientationFlow(): Flow<OrientationReading> = callbackFlow {
        if (rotationVectorSensor == null) {
            close(Exception("Rotation Vector Sensor not available"))
            return@callbackFlow
        }

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event == null) return

                // 1) Matrices + orientación
                val rotationMatrix = FloatArray(9)
                val orientation = FloatArray(3)
                SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                SensorManager.getOrientation(rotationMatrix, orientation)

                // 2) Pasar a grados
                val yawDeg0_360 = ((Math.toDegrees(orientation[0].toDouble()).toFloat() + 360f) % 360f)
                val pitchDeg = Math.toDegrees(orientation[1].toDouble()).toFloat()
                val rollDeg  = Math.toDegrees(orientation[2].toDouble()).toFloat()

                // 3) Convertir yaw a –180..180 (mejor para control)
                val yawDegRaw = toMinus180To180(yawDeg0_360)
                lastYawRawDeg = yawDegRaw

                // 4) Aplicar offset de calibración
                val yawDegCalibrated = toMinus180To180(yawDegRaw - yawOffsetDeg)

                trySend(
                    OrientationReading(
                        yaw = yawDegCalibrated,
                        pitch = pitchDeg,
                        roll = rollDeg,
                        timestamp = event.timestamp
                    )
                )
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        sensorManager.registerListener(
            listener,
            rotationVectorSensor,
            SensorManager.SENSOR_DELAY_GAME
        )

        awaitClose { sensorManager.unregisterListener(listener) }
    }

    /**
     * Botón "Calibrar": fija el rumbo actual como 0°.
     * Es decir, guarda offset = yaw_raw_actual.
     */
    fun calibrateHeadingToCurrent() {
        yawOffsetDeg = lastYawRawDeg
        prefs.edit().putFloat("yaw_offset_deg", yawOffsetDeg).apply()
    }

    /**
     * Variante: fija que el rumbo actual pase a 'desiredZeroDeg'.
     * Por ejemplo, desiredZeroDeg = +90 → tras pulsar,
     * la lectura calibrada mostrará ~+90° en la orientación actual.
     */
    fun setDesiredZero(desiredZeroDeg: Float) {
        // Queremos: yaw_cal = to180(yaw_raw - offset) ≈ desiredZeroDeg cuando yaw_raw = lastYawRawDeg
        // => offset ≈ yaw_raw - desiredZeroDeg
        val desired = toMinus180To180(desiredZeroDeg)
        yawOffsetDeg = toMinus180To180(lastYawRawDeg - desired)
        prefs.edit().putFloat("yaw_offset_deg", yawOffsetDeg).apply()
    }

    /** Quita la calibración */
    fun resetCalibration() {
        yawOffsetDeg = 0f
        prefs.edit().putFloat("yaw_offset_deg", yawOffsetDeg).apply()
    }

    // --- Helpers de ángulo ---
    private fun toMinus180To180(deg0_360: Float): Float {
        var x = (deg0_360 % 360f + 360f) % 360f
        if (x > 180f) x -= 360f
        return x
    }
}
