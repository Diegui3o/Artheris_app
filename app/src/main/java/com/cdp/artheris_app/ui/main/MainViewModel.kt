package com.cdp.artheris_app.ui.main

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cdp.artheris_app.data.sensors.AccelerometerReading
import com.cdp.artheris_app.data.sensors.AccelerometerRepository
import com.cdp.artheris_app.data.sensors.GyroscopeReading
import com.cdp.artheris_app.data.sensors.GyroscopeRepository
import com.cdp.artheris_app.data.sensors.AnglesReading
import com.cdp.artheris_app.data.sensors.AnglesRepository
import com.cdp.artheris_app.data.sensors.KalmanRepository
import com.cdp.artheris_app.data.sensors.AnglesFilteredReading
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val accelRepo = AccelerometerRepository(application.applicationContext)
    private val gyroRepo  = GyroscopeRepository(application.applicationContext)
    private val anglesRepo = AnglesRepository(application.applicationContext)
    private val kalmanRepo = KalmanRepository(application.applicationContext)

    private val _accel = MutableStateFlow<AccelerometerReading?>(null)
    val accel: StateFlow<AccelerometerReading?> = _accel
    private val _gyro = MutableStateFlow<GyroscopeReading?>(null)
    val gyro: StateFlow<GyroscopeReading?> = _gyro
    private val _angles = MutableStateFlow<AnglesReading?>(null)
    val angles: StateFlow<AnglesReading?> = _angles
    private val _filteredAngles = MutableStateFlow<AnglesFilteredReading?>(null)
    val filteredAngles: StateFlow<AnglesFilteredReading?> = _filteredAngles

    init {
        accelRepo.accelerometerFlow().onEach { _accel.value = it }.launchIn(viewModelScope)
        gyroRepo.gyroscopeFlow().onEach { _gyro.value = it }.launchIn(viewModelScope)
        anglesRepo.anglesFlow().onEach { _angles.value = it }.launchIn(viewModelScope)
        kalmanRepo.filteredAnglesFlow().onEach { _filteredAngles.value = it }.launchIn(viewModelScope)
    }
}
