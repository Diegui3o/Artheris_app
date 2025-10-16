package com.cdp.artheris_app.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun AccelerometerScreen(mainViewModel: MainViewModel = viewModel()) {

    val accelState by mainViewModel.accel.collectAsState()
    val gyroState  by mainViewModel.gyro.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(WindowInsets.statusBars.asPaddingValues())
            .padding(16.dp),
        verticalArrangement = Arrangement.Top,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color(0xFF769FE8)
            )
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Proyecto: Artheris", fontSize = 20.sp, color = Color.White)
                Text("Modo: Sensores en tiempo real", fontSize = 14.sp, color = Color.White)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(9.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color(0xFFC8C2EF)
            )
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Acelerómetro (X/Y/Z)", fontSize = 18.sp, color = Color.Black)
                Spacer(modifier = Modifier.height(8.dp))

                ValueRow(label = "X", value = accelState?.x)
                Spacer(modifier = Modifier.height(8.dp))
                ValueRow(label = "Y", value = accelState?.y)
                Spacer(modifier = Modifier.height(8.dp))
                ValueRow(label = "Z", value = accelState?.z)
                Spacer(modifier = Modifier.height(8.dp))
                Text("Timestamp: ${accelState?.timestamp ?: "--"}", color = Color.DarkGray)
            }
        }

        Button(onClick = { /* Calibrar offset */ }) {
            Text("Calibrar offset")
        }
        Spacer(modifier = Modifier.height(12.dp))

        // Gyroscope card
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(9.dp),
            colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = Color(0xFFDDDDFF))
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Giroscopio (°/s)", fontSize = 18.sp, color = Color.Black)
                Spacer(modifier = Modifier.height(8.dp))
                ValueRow(label = "X", value = gyroState?.x)
                Spacer(modifier = Modifier.height(6.dp))
                ValueRow(label = "Y", value = gyroState?.y)
                Spacer(modifier = Modifier.height(6.dp))
                ValueRow(label = "Z", value = gyroState?.z)
                Spacer(modifier = Modifier.height(8.dp))
                Text("Timestamp: ${gyroState?.timestamp ?: "--"}", color = Color.DarkGray)
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        Button(onClick = { /* Nueva orientacion */ }) {
            Text("Calibrar magnetometro")
        }
        Button(onClick = { /* Cambiar parametros */ }) {
            Text("Cambiar parametros")
        }
    }
}

@Composable
private fun ValueRow(label: String, value: Float?) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(text = "$label:", fontSize = 16.sp)
        Text(text = value?.let { String.format("%.3f", it) } ?: "--", fontSize = 16.sp)
    }
}
