package com.cdp.artheris_app.data.config

import kotlinx.serialization.Serializable

@Serializable
data class FieldConfig(
    val key: String,
    val enabled: Boolean,
    val alias: String
)

@Serializable
data class TelemetryConfig(
    val fields: List<FieldConfig>
) {
    companion object {
        fun default(): TelemetryConfig {
            // Por defecto, activar rotación principal y gx/gy/gz/ax/ay/az
            val defaults = listOf(
                TelemetryField.YAW_ROT,
                TelemetryField.PITCH_ROT,
                TelemetryField.ROLL_ROT,
                TelemetryField.ACCEL_X,
                TelemetryField.ACCEL_Y,
                TelemetryField.ACCEL_Z,
                TelemetryField.GYRO_X,
                TelemetryField.GYRO_Y,
                TelemetryField.GYRO_Z
            )
            val all = TelemetryField.values().map { field ->
                FieldConfig(
                    key = field.key,
                    enabled = field in defaults,
                    alias = field.defaultAlias
                )
            }
            return TelemetryConfig(fields = all)
        }
    }
}
