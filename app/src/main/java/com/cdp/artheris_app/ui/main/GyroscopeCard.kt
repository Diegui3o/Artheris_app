package com.cdp.artheris_app.ui.main

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.graphics.Color

@Composable
fun GyroscopeCard(
    gx: Float?,
    gy: Float?,
    gz: Float?,
    timestamp: Any? = null,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(9.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFDDDDFF))
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Giroscopio (°/s)", fontSize = 18.sp, color = Color.Black)
            Spacer(modifier = Modifier.height(8.dp))
            ValueRow(label = "GyroX", value = gx)
            Spacer(modifier = Modifier.height(6.dp))
            ValueRow(label = "GyroY", value = gy)
            Spacer(modifier = Modifier.height(6.dp))
            ValueRow(label = "GyroZ", value = gz)
            Spacer(modifier = Modifier.height(8.dp))
            Text("Timestamp: ${timestamp ?: "--"}", color = Color.DarkGray, fontSize = 12.sp)
        }
    }
}
