import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Clase para manejar la URL del servidor de forma persistente
class ServerUrlManager {
  // URL por defecto, usada como respaldo
  static const String defaultServerUrl = 'http://192.168.1.11:3002';
  
  // Clave para almacenar la URL en SharedPreferences
  static const String _serverUrlKey = 'server_url';
  
  // Instancia singleton
  static final ServerUrlManager _instance = ServerUrlManager._internal();
  
  // Constructor privado
  ServerUrlManager._internal();
  
  // Fábrica para obtener la instancia
  factory ServerUrlManager() => _instance;
  
  // Obtener la URL del servidor guardada o la predeterminada
  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? defaultServerUrl;
  }
  
  // Guardar la URL del servidor
  Future<bool> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_serverUrlKey, url);
  }
  
  // Obtener la URL base (sin la ruta)
  Future<Uri> getBaseUri() async {
    final url = await getServerUrl();
    final uri = Uri.parse(url);
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
    );
  }
  
  // Verificar si la URL del servidor es accesible
  Future<bool> isServerReachable() async {
    try {
      final uri = await getBaseUri();
      final request = await HttpClient().headUrl(uri);
      final response = await request.close();
      return response.statusCode < 400;
    } catch (e) {
      return false;
    }
  }
  
  // Obtener la dirección IP local del dispositivo
  Future<String?> getLocalIpAddress() async {
    try {
      final info = NetworkInfo();
      return await info.getWifiIP();
    } catch (e) {
      debugPrint('Error al obtener la dirección IP: $e');
      return null;
    }
  }
  
  // Escanear la red local en busca de servidores
  Future<List<String>> scanLocalNetwork({int port = 3002}) async {
    final localIp = await getLocalIpAddress();
    if (localIp == null) return [];
    
    final ipParts = localIp.split('.');
    if (ipParts.length != 4) return [];
    
    final baseIp = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}.';
    final servers = <String>[];
    
    // Escanear solo las primeras 10 direcciones IP para no sobrecargar
    for (var i = 1; i <= 10; i++) {
      final ip = '$baseIp$i';
      try {
        final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 500));
        await socket.close();
        servers.add('http://$ip:$port');
      } catch (e) {
        // Ignorar errores de conexión
      }
    }
    
    return servers;
  }
}
