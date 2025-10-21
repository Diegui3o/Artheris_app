package com.cdp.artheris_app.data.net

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.endpointsDS by preferencesDataStore("udp_endpoints")

class EndpointsRepository(private val context: Context) {

    companion object {
        private const val REMOTE_PORT = 8888 // fijo, no editable
        private val KEY_SET   = stringSetPreferencesKey("endpoints_set")   // Set<String> "ip:port"
        private val KEY_ACTIVE= stringPreferencesKey("active_endpoint")    // String  "ip:port"
    }

    /** Devuelve solo las IPs (sin puerto) */
    val ipsFlow: Flow<List<String>> =
        context.endpointsDS.data.map { prefs ->
            (prefs[KEY_SET] ?: emptySet())
                .map { it.substringBefore(":") }
                .distinct()
                .sorted()
        }

    /** Devuelve la IP activa (sin puerto) o null */
    val activeIpFlow: Flow<String?> =
        context.endpointsDS.data.map { prefs ->
            prefs[KEY_ACTIVE]?.substringBefore(":")
        }

    /** Agregar IP (se guarda como "ip:REMOTE_PORT") */
    suspend fun addIp(ip: String) {
        val ep = "$ip:$REMOTE_PORT"
        context.endpointsDS.edit { prefs ->
            val set = (prefs[KEY_SET] ?: emptySet()).toMutableSet()
            set.add(ep)
            prefs[KEY_SET] = set
            if (prefs[KEY_ACTIVE].isNullOrBlank()) {
                prefs[KEY_ACTIVE] = ep
            }
        }
    }

    /** Eliminar IP (borra "ip:REMOTE_PORT"); si era activa, selecciona otra o limpia */
    suspend fun removeIp(ip: String) {
        val ep = "$ip:$REMOTE_PORT"
        context.endpointsDS.edit { prefs ->
            val set = (prefs[KEY_SET] ?: emptySet()).toMutableSet()
            set.remove(ep)
            prefs[KEY_SET] = set

            if (prefs[KEY_ACTIVE] == ep) {
                val next = set.firstOrNull()
                if (next != null) prefs[KEY_ACTIVE] = next
                else prefs.remove(KEY_ACTIVE) // ¡importante! no asignes null a StringPref
            }
        }
    }

    /** Marcar IP como activa (se guarda "ip:REMOTE_PORT") */
    suspend fun setActiveIp(ip: String) {
        val ep = "$ip:$REMOTE_PORT"
        context.endpointsDS.edit { prefs ->
            prefs[KEY_ACTIVE] = ep
            val set = (prefs[KEY_SET] ?: emptySet()).toMutableSet()
            if (!set.contains(ep)) {
                set.add(ep)
                prefs[KEY_SET] = set
            }
        }
    }
}
