package com.cdp.artheris_app.ui.main

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cdp.artheris_app.data.net.EndpointsRepository
import com.cdp.artheris_app.data.net.UdpClient
import com.cdp.artheris_app.data.config.TelemetryConfig
import com.cdp.artheris_app.data.config.TelemetryConfigRepository
import com.cdp.artheris_app.data.sensors.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.JsonNull

class MainViewModel(application: Application) : AndroidViewModel(application) {

    private val LOCAL_PORT  = 8889
    private val REMOTE_PORT = 8888

    // === Repos de sensores ===
    private val accelRepo    = AccelerometerRepository(application.applicationContext)
    private val gyroRepo     = GyroscopeRepository(application.applicationContext)
    private val anglesRepo   = AnglesRepository(application.applicationContext)
    private val kalmanRepo   = KalmanRepository(application.applicationContext)
    private val rotationRepo = RotationVectorRepository(application.applicationContext)

    // === Flows de sensores ===
    val orientation = rotationRepo.getOrientationFlow()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(), null)

    private val _accel = MutableStateFlow<AccelerometerReading?>(null)
    val accel: StateFlow<AccelerometerReading?> = _accel

    private val _gyro = MutableStateFlow<GyroscopeReading?>(null)
    val gyro: StateFlow<GyroscopeReading?> = _gyro

    private val _angles = MutableStateFlow<AnglesReading?>(null)
    val angles: StateFlow<AnglesReading?> = _angles

    private val _filteredAngles = MutableStateFlow<AnglesFilteredReading?>(null)
    val filteredAngles: StateFlow<AnglesFilteredReading?> = _filteredAngles

    // === Config (qué enviar y alias) ===
    private val telemetryRepo = TelemetryConfigRepository(application.applicationContext)
    val telemetryConfig = telemetryRepo.configFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TelemetryConfig.default())

    // Endpoints (IPs + activa)
    private val endpointsRepo = EndpointsRepository(application.applicationContext)
    val endpoints = endpointsRepo.ipsFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val activeEndpoint = endpointsRepo.activeIpFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun addEndpoint(ip: String) = viewModelScope.launch { endpointsRepo.addIp(ip) }
    fun removeEndpoint(ip: String) = viewModelScope.launch { endpointsRepo.removeIp(ip) }
    fun setActiveEndpoint(ip: String) = viewModelScope.launch { endpointsRepo.setActiveIp(ip) }

    fun setFieldEnabled(key: String, enabled: Boolean) = viewModelScope.launch {
        telemetryRepo.setFieldEnabled(key, enabled)
    }

    fun setFieldAlias(key: String, alias: String) = viewModelScope.launch {
        telemetryRepo.setFieldAlias(key, alias)
    }
    // === Init: suscribir sensores ===
    init {
        accelRepo.accelerometerFlow().onEach { _accel.value = it }.launchIn(viewModelScope)
        gyroRepo.gyroscopeFlow().onEach { _gyro.value = it }.launchIn(viewModelScope)
        anglesRepo.anglesFlow().onEach { _angles.value = it }.launchIn(viewModelScope)
        kalmanRepo.filteredAnglesFlow().onEach { _filteredAngles.value = it }.launchIn(viewModelScope)
    }

    // === Calibración de yaw ===
    fun calibrateHeadingToCurrent() { rotationRepo.calibrateHeadingToCurrent() }
    fun setHeadingDesiredZero(deg: Float) { rotationRepo.setDesiredZero(deg) }
    fun resetHeadingCalibration() { rotationRepo.resetCalibration() }

    private fun buildTelemetryJson(): String {
        val cfg = telemetryConfig.value
        val o = orientation.value
        val a = accel.value
        val g = gyro.value
        val f = filteredAngles.value
        val an = angles.value

        val obj = buildJsonObject {
            put("timestamp_ms", System.currentTimeMillis())
            cfg.fields.filter { it.enabled }.forEach { fc ->
                val value: Number? = when (fc.key) {
                    "yaw_rot"   -> o?.yaw
                    "pitch_rot" -> o?.pitch
                    "roll_rot"  -> o?.roll
                    "roll_accel"   -> an?.roll_est
                    "pitch_accel"  -> an?.pitch_est
                    "roll_kalman"  -> f?.roll
                    "pitch_kalman" -> f?.pitch
                    "roll_gyro"  -> g?.degPerSecX
                    "pitch_gyro" -> g?.degPerSecY
                    "accel_x" -> a?.x
                    "accel_y" -> a?.y
                    "accel_z" -> a?.z
                    "gyro_x"  -> g?.degPerSecX
                    "gyro_y"  -> g?.degPerSecY
                    "gyro_z"  -> g?.degPerSecZ
                    else -> null
                }
                if (value == null) put(fc.alias, JsonNull) else put(fc.alias, value)
            }
        }
        return Json.encodeToString(obj)
    }

    fun sendTelemetryTo(host: String, port: Int = REMOTE_PORT) = viewModelScope.launch {
        val jsonString = buildTelemetryJson()
        UdpClient.send(host, port, jsonString.toByteArray(Charsets.UTF_8))
    }

    fun sendTelemetryToActive() {
        val ip = activeEndpoint.value ?: return
        sendTelemetryTo(ip, REMOTE_PORT)
    }
}
