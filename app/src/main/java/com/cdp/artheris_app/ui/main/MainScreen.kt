package com.cdp.artheris_app.ui.main

import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cdp.artheris_app.data.sensors.AccelerometerReading
import com.cdp.artheris_app.data.sensors.AnglesFilteredReading
import com.cdp.artheris_app.data.sensors.GyroscopeReading

@Composable
fun MainScreen(mainViewModel: MainViewModel = viewModel()) {
    
    val accelState by mainViewModel.accel.collectAsState()
    val gyroState  by mainViewModel.gyro.collectAsState()
    val anglesState by mainViewModel.angles.collectAsState()
    val filteredAnglesState by mainViewModel.filteredAngles.collectAsState(initial = null as AnglesFilteredReading?)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(WindowInsets.statusBars.asPaddingValues())
            .padding(16.dp),
        verticalArrangement = Arrangement.Top,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        HeaderCard()

        Spacer(modifier = Modifier.height(16.dp))

        AccelerometerCard(
            x = accelState?.x,
            y = accelState?.y,
            z = accelState?.z,
            timestamp = accelState?.timestamp,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(12.dp))

        GyroscopeCard(
            gx = gyroState?.degPerSecX,
            gy = gyroState?.degPerSecY,
            gz = gyroState?.degPerSecZ,
            timestamp = gyroState?.timestamp,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(12.dp))

        AnglesCard(
            roll_est = anglesState?.roll_est,
            pitch_est = anglesState?.pitch_est,
            timestamp = anglesState?.timestamp,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(12.dp))

        AnglesFilteredCard(
            roll = filteredAnglesState?.roll,
            pitch = filteredAnglesState?.pitch,
            timestamp = filteredAnglesState?.timestamp,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Botones: aquí pongo lambdas vacías para que compile; si añades funciones en el ViewModel,
        ActionButtons(
            onCalibrateAccel = { /* TODO: reemplazar por mainViewModel.calibrateAccel() si existe */ },
            onCalibrateMag   = { /* TODO: reemplazar por mainViewModel.calibrateMagnetometer() si existe */ },
            onChangeParams   = { /* navegar o abrir dialogo */ }
        )
    }
}
