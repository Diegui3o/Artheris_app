package com.cdp.artheris_app.data.config

enum class TelemetryField(val key: String, val defaultAlias: String) {
    // Orientación
    YAW_ROT("yaw_rot", "yaw"),
    PITCH_ROT("pitch_rot", "pitch"),
    ROLL_ROT("roll_rot", "roll"),

    // Variantes de roll/pitch si tienes de varias fuentes:
    ROLL_ACCEL("roll_accel", "roll_acc"),
    ROLL_GYRO("roll_gyro", "roll_gyro"),
    ROLL_KALMAN("roll_kalman", "roll_kf"),

    PITCH_ACCEL("pitch_accel", "pitch_acc"),
    PITCH_GYRO("pitch_gyro", "pitch_gyro"),
    PITCH_KALMAN("pitch_kalman", "pitch_kf"),

    // Acelerómetro vector
    ACCEL_X("accel_x", "ax"),
    ACCEL_Y("accel_y", "ay"),
    ACCEL_Z("accel_z", "az"),

    // Giroscopio vector
    GYRO_X("gyro_x", "gx"),
    GYRO_Y("gyro_y", "gy"),
    GYRO_Z("gyro_z", "gz"),
}
