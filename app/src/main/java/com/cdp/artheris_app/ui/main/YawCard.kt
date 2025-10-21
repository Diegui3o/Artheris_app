package com.cdp.artheris_app.ui.main

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.cdp.artheris_app.data.sensors.OrientationReading

@Composable
fun YawCard(
    orientation: OrientationReading?,
    modifier: Modifier = Modifier
) {
    SensorCard(
        title = "Orientation (Yaw / Pitch / Roll)",
        modifier = modifier
    ) {
        InfoRow(label = "Yaw (°)", value = orientation?.yaw?.let { "%.2f".format(it) } ?: "--")
        InfoRow(label = "Pitch (°)", value = orientation?.pitch?.let { "%.2f".format(it) } ?: "--")
        InfoRow(label = "Roll (°)", value = orientation?.roll?.let { "%.2f".format(it) } ?: "--")
        InfoRow(label = "Timestamp", value = orientation?.timestamp?.toString() ?: "--")
    }
}

@Composable
fun InfoRow(label: String, value: String) {
    androidx.compose.foundation.layout.Row {
        androidx.compose.material3.Text(
            text = "$label: $value"
        )
    }
}
