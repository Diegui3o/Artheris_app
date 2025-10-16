package com.cdp.artheris_app.ui.main

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cdp.artheris_app.data.sensors.AccelerometerReading
import com.cdp.artheris_app.data.sensors.AccelerometerRepository
import com.cdp.artheris_app.data.sensors.GyroscopeReading
import com.cdp.artheris_app.data.sensors.GyroscopeRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val accelRepo = AccelerometerRepository(application.applicationContext)
    private val gyroRepo  = GyroscopeRepository(application.applicationContext)

    private val _accel = MutableStateFlow<AccelerometerReading?>(null)
    val accel: StateFlow<AccelerometerReading?> = _accel

    private val _gyro = MutableStateFlow<GyroscopeReading?>(null)
    val gyro: StateFlow<GyroscopeReading?> = _gyro

    init {
        accelRepo.accelerometerFlow().onEach { _accel.value = it }.launchIn(viewModelScope)
        gyroRepo.gyroscopeFlow().onEach { _gyro.value = it }.launchIn(viewModelScope)
    }
}
