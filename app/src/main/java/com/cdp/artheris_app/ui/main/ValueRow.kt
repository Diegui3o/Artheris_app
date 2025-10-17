package com.cdp.artheris_app.ui.main

import android.annotation.SuppressLint
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer

@SuppressLint("DefaultLocale")
@Composable
fun ValueRow(label: String, value: Float?) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(text = "$label:", fontSize = 16.sp)
        Spacer(modifier = Modifier.weight(1f))
        Text(text = value?.let { String.format("%.3f", it) } ?: "--", fontSize = 16.sp)
    }
}
