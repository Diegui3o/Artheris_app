package com.cdp.artheris_app.ui.main

import androidx.compose.foundation.layout.Column
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
fun HeaderCard(
    projectName: String = "Proyecto: Artheris",
    modeText: String = "Modo: Sensores en tiempo real",
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF769FE8))
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = projectName, fontSize = 20.sp, color = Color.White)
            Text(text = modeText, fontSize = 14.sp, color = Color.White)
        }
    }
}
