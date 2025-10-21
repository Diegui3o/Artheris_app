package com.cdp.artheris_app.ui.main

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun ActionButtons(
    onCalibrateAccel: () -> Unit = {},
    onCalibrateMag: () -> Unit = {},
    onChangeParams: () -> Unit = {}
) {
    Column {
        Button(onClick = onCalibrateAccel) { Text("Calibrar offset") }
        Spacer(modifier = Modifier.height(6.dp))
        Button(onClick = onChangeParams) { Text("Cambiar parametros") }
    }
}
