package com.cdp.artheris_app.ui.main

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun YawControls(
    onCalibrateZeroNow: () -> Unit,
    modifier: Modifier = Modifier
) {
    Spacer(modifier = Modifier.height(8.dp))
    Row(
        modifier = modifier
            .fillMaxWidth(),
        horizontalArrangement = Arrangement.Center // centrado
    ) {
        Button(onClick = onCalibrateZeroNow) {
            Text("Calibrar rumbo (0°)")
        }
    }
}
