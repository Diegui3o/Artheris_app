package com.cdp.artheris_app.data.telemetry

import kotlinx.serialization.Serializable

@Serializable
data class TelemetryPayload(
    val ts_nanos: Long,
    val yaw_deg: Float? = null,
    val pitch_deg: Float? = null,
    val roll_deg: Float? = null,
    val accel: Accel? = null,
    val gyro: Gyro? = null
) {
    @Serializable data class Accel(val x: Float?, val y: Float?, val z: Float?)
    @Serializable data class Gyro(val gx: Float?, val gy: Float?, val gz: Float?)
}
