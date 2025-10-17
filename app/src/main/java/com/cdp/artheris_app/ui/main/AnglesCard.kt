package com.cdp.artheris_app.ui.main

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun AnglesCard(
    roll_est: Float?,
    pitch_est: Float?,
    timestamp: Long?,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(9.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFCCE8CC))
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Ángulos estimados (°)", fontSize = 18.sp, color = Color.Black)
            Spacer(modifier = Modifier.height(8.dp))

            ValueRow(label = "Roll", value = roll_est)
            Spacer(modifier = Modifier.height(6.dp))
            ValueRow(label = "Pitch", value = pitch_est)

            Spacer(modifier = Modifier.height(8.dp))
            Text("Timestamp: ${timestamp ?: "--"}", color = Color.DarkGray)
        }
    }
}
