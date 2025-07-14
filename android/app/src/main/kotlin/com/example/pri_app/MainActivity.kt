package com.example.pri_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import androidx.annotation.NonNull

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.pri_app/mali_logging"

        override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setMaliLoggingLevel" -> {
                    try {
                        // Set system property to reduce Mali GPU debug logs
                        System.setProperty("debug.mali.log.level", "error")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Failed to set Mali logging level", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
