package com.cdp.artheris_app.ui.main

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun AnglesFilteredCard(
    roll: Float?,
    pitch: Float?,
    timestamp: Long?,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(9.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFD6E8FF))
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Ángulos filtrados (Kalman) (°)", fontSize = 18.sp, color = Color.Black)
            Spacer(modifier = Modifier.height(8.dp))

            ValueRow(label = "Roll (K)", value = roll)
            Spacer(modifier = Modifier.height(6.dp))
            ValueRow(label = "Pitch (K)", value = pitch)

            Spacer(modifier = Modifier.height(8.dp))
            Text("Timestamp: ${timestamp ?: "--"}", color = Color.DarkGray)
        }
    }
}
