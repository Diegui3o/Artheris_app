package com.cdp.artheris_app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cdp.artheris_app.data.config.TelemetryConfig
import com.cdp.artheris_app.ui.main.MainViewModel

@Composable
fun WifiScreen(vm: MainViewModel = viewModel()) {
    val cfg by vm.telemetryConfig.collectAsState()

    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("Wi-Fi: Campos a enviar y alias", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(12.dp))

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(cfg.fields, key = { it.key }) { f ->
                FieldRow(
                    key = f.key,
                    enabled = f.enabled,
                    alias = f.alias,
                    onEnabledChange = { vm.setFieldEnabled(f.key, it) },
                    onAliasChange = { vm.setFieldAlias(f.key, it) }
                )
            }
        }
    }
}

@Composable
private fun FieldRow(
    key: String,
    enabled: Boolean,
    alias: String,
    onEnabledChange: (Boolean) -> Unit,
    onAliasChange: (String) -> Unit
) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(12.dp)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(text = key)
                Switch(checked = enabled, onCheckedChange = onEnabledChange)
            }
            Spacer(Modifier.height(8.dp))
            var aliasState by remember(key) { mutableStateOf(TextFieldValue(alias)) }
            OutlinedTextField(
                value = aliasState,
                onValueChange = {
                    aliasState = it
                    onAliasChange(it.text)
                },
                label = { Text("Alias") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
