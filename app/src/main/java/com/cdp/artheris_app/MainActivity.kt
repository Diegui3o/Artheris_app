package com.cdp.artheris_app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.cdp.artheris_app.ui.main.AccelerometerScreen
import com.cdp.artheris_app.ui.theme.Artheris_appTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            Artheris_appTheme {
                AccelerometerScreen()
            }
        }
    }
}
