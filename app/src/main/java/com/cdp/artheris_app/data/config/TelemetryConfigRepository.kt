package com.cdp.artheris_app.data.config

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json
import kotlinx.serialization.decodeFromString   // ← IMPORT NECESARIO
import kotlinx.serialization.encodeToString   // ← IMPORT NECESARIO

private val Context.telemetryDataStore by preferencesDataStore("telemetry_config")

class TelemetryConfigRepository(private val context: Context) {

    private val KEY = stringPreferencesKey("config_json")
    private val json = Json {
        ignoreUnknownKeys = true
        prettyPrint = false
    }

    val configFlow: Flow<TelemetryConfig> =
        context.telemetryDataStore.data.map { prefs ->
            val raw = prefs[KEY]
            if (raw.isNullOrBlank()) {
                TelemetryConfig.default()
            } else {
                runCatching { json.decodeFromString<TelemetryConfig>(raw) }
                    .getOrElse { TelemetryConfig.default() }
            }
        }

    suspend fun setFieldEnabled(key: String, enabled: Boolean) {
        update { cfg ->
            val updated = cfg.fields.map {
                if (it.key == key) it.copy(enabled = enabled) else it
            }
            cfg.copy(fields = updated)
        }
    }

    suspend fun setFieldAlias(key: String, alias: String) {
        update { cfg ->
            val updated = cfg.fields.map {
                if (it.key == key) it.copy(alias = alias) else it
            }
            cfg.copy(fields = updated)
        }
    }

    private suspend fun update(transform: (TelemetryConfig) -> TelemetryConfig) {
        context.telemetryDataStore.edit { prefs ->
            val current = prefs[KEY]?.let { raw ->
                runCatching { json.decodeFromString<TelemetryConfig>(raw) }.getOrNull()
            } ?: TelemetryConfig.default()

            val newCfg = transform(current)
            prefs[KEY] = json.encodeToString(newCfg)
        }
    }
}
