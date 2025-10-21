package com.cdp.artheris_app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cdp.artheris_app.ui.main.MainViewModel

@Composable
fun SettingsScreen(vm: MainViewModel = viewModel()) {
    val endpoints by vm.endpoints.collectAsState()
    val active by vm.activeEndpoint.collectAsState()

    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("Endpoint activo (IP)", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = active ?: "",
            onValueChange = {},
            label = { Text("IP actual") },
            readOnly = true,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(16.dp))
        Text("Seleccionar endpoint", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))

        LazyColumn(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(endpoints, key = { it }) { ip ->
                Card(Modifier.fillMaxWidth()) {
                    Row(
                        Modifier.padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(Modifier.weight(1f)) {
                            RadioButton(
                                selected = (active == ip),
                                onClick = { vm.setActiveEndpoint(ip) }
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(ip)
                        }
                        OutlinedButton(onClick = { vm.removeEndpoint(ip) }) {
                            Text("Eliminar")
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(16.dp))
        AddIpSection(onAdd = { ip -> vm.addEndpoint(ip) })
    }
}

@Composable
private fun AddIpSection(onAdd: (String) -> Unit) {
    var ip by remember { mutableStateOf("") }

    Text("Agregar IP", style = MaterialTheme.typography.titleMedium)
    Spacer(Modifier.height(8.dp))
    OutlinedTextField(
        value = ip,
        onValueChange = { ip = it },
        label = { Text("IP (ej. 10.0.2.2 o 192.168.1.50)") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        modifier = Modifier.fillMaxWidth()
    )
    Spacer(Modifier.height(8.dp))
    val valid = remember(ip) { isValidIPv4(ip) }
    Button(
        onClick = {
            if (valid) {
                onAdd(ip.trim())
                ip = ""
            }
        },
        enabled = valid
    ) {
        Text("Añadir")
    }
}

// Valida IPv4 simple (0-255)
private fun isValidIPv4(ip: String): Boolean {
    val parts = ip.trim().split(".")
    if (parts.size != 4) return false
    return parts.all {
        val n = it.toIntOrNull() ?: return false
        n in 0..255 && !(it.startsWith("0") && it != "0" && it.length > 1)
    }
}
