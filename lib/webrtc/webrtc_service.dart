import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class WebRTCService {
  static const Duration _connectionTimeout = Duration(seconds: 15);
  
  final String serverUrl;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  io.Socket? _socket;
  String? _roomId;
  final Completer<void> _signalingReadyCompleter = Completer<void>();
  List<MediaDeviceInfo> _availableCameras = [];
  int _currentCameraIndex = 0;
  bool _isDisposed = false;
  
  WebRTCService({required this.serverUrl});

  // Callback para cuando la conexión se establece
  Function(RTCIceConnectionState)? onIceConnectionStateChange;

  // Get the current camera device info
  MediaDeviceInfo? get currentCamera => _availableCameras.isNotEmpty
      ? _availableCameras[_currentCameraIndex]
      : null;

  // Get current camera index
  int get currentCameraIndex => _currentCameraIndex;

  // Check if current camera is front-facing
  bool get isFrontCamera =>
      currentCamera?.label.toLowerCase().contains('front') ?? false;

  // Get available cameras list
  List<MediaDeviceInfo> get availableCameras =>
      List.unmodifiable(_availableCameras);

  // Getter para exponer el stream local de forma segura
  MediaStream? get localStream => _localStream;

  Future<void> initialize(String roomId) async {
    if (_isDisposed) {
      throw StateError('WebRTCService has been disposed');
    }

    _roomId = roomId;
    debugPrint('🔄 Conectando a $serverUrl...');

    try {
      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setReconnectionAttempts(3)
            .setReconnectionDelay(1000)
            .build(),
      );

      _setupSignaling();
      _socket!.connect();
      
      return _signalingReadyCompleter.future.timeout(
        _connectionTimeout,
        onTimeout: () {
          _socket?.disconnect();
          throw TimeoutException('No se pudo conectar al servidor después de ${_connectionTimeout.inSeconds} segundos');
        },
      );
    } catch (e) {
      debugPrint('❌ Error al inicializar WebRTCService: $e');
      await dispose();
      rethrow;
    }
  }

  void _setupSignaling() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      if (_isDisposed) {
        _socket?.disconnect();
        return;
      }
      
      debugPrint('✅ SIGNAL: Conectado al servidor de señalización!');
      debugPrint('2. Uniéndose a la sala: $_roomId');
      
      try {
        _socket!.emit('join', _roomId);
      } catch (e) {
        debugPrint('❌ Error al unirse a la sala: $e');
        _signalingReadyCompleter.completeError(e);
        return;
      }
      
      _socket!.onError((data) => debugPrint('❌ ERROR de Socket: $data'));
      _socket!.on('error', (data) => debugPrint('❌ ERROR del Servidor: $data'));
    });

    _socket!.on('joined', (_) {
      print('✅ SIGNAL: Confirmación de unión a la sala recibida.');
      if (!_signalingReadyCompleter.isCompleted) {
        _signalingReadyCompleter.complete();
      }
    });

    _socket!.on('answer', (data) async {
      if (_peerConnection == null) return;
      print('<- REMOTE: Respuesta recibida del par.');
      try {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']),
        );
        print('✅ PC: RemoteDescription (respuesta) establecida.');
      } catch (e) {
        print('❌ ERROR al establecer la respuesta: $e');
      }
    });

    _socket!.on('candidate', (data) async {
      if (_peerConnection == null || data['candidate'] == null) return;
      print('<- REMOTE: Candidato ICE recibido.');
      try {
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ),
        );
        print('✅ PC: Candidato ICE añadido.');
      } catch (e) {
        print('❌ ERROR al añadir candidato ICE: $e');
      }
    });

    _socket!.onDisconnect((_) {
      print('🔌 SIGNAL: Desconectado del servidor de señalización.');
    });
  }

  Future<void> _createPeerConnection() async {
    print('3. Creando PeerConnection...');

    try {
      final configuration = <String, dynamic>{
        'iceServers': [
          // Servidores STUN públicos
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
        'iceTransportPolicy': 'all',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
        'iceCandidatePoolSize': 10,
      };

      print('🔧 Configuración de PeerConnection: $configuration');

      _peerConnection = await createPeerConnection(configuration);

      if (_peerConnection == null) {
        throw Exception('No se pudo crear la conexión PeerConnection');
      }

      _peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) async {
        if (candidate == null || candidate.candidate == null) {
          print('⚠️ Candidato ICE nulo recibido');
          return;
        }

        print(
          '-> LOCAL: Enviando candidato ICE: ${candidate.candidate!.substring(0, 50)}...',
        );
        try {
          _socket!.emit('candidate', {
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            'roomId': _roomId,
          });
        } catch (e) {
          print('❌ Error al enviar candidato ICE: $e');
        }
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('ℹ️ Estado de conexión ICE: $state');
        onIceConnectionStateChange?.call(state);

        // Manejar cambios de estado
        print('🔄 Estado ICE actual: $state');
        if (state.toString().contains('failed')) {
          print('❌ La conexión ICE falló');
        } else if (state.toString().contains('disconnected')) {
          print('⚠️ La conexión ICE se desconectó');
        } else if (state.toString().contains('connected') ||
            state.toString().contains('completed')) {
          print('✅ Conexión ICE establecida');
        }
      };

      // Manejar eventos de señalización
      _peerConnection!.onSignalingState = (RTCSignalingState state) {
        print('📶 Estado de señalización: $state');
      };

      // Enhanced ICE gathering state debugging
      print('🔄 Setting up ICE gathering state listener...');

      _peerConnection!.onIceGatheringState = (state) {
        print('\n❄️ ===== ICE GATHERING STATE CHANGED =====');
        print('❄️ State: $state');
        print('❄️ Runtime Type: ${state.runtimeType}');
        print('❄️ String Value: "$state"');
        print('❄️ Index: ${state.index}');

        // Try to detect completion state
        final stateStr = state.toString().toLowerCase();
        if (stateStr.contains('complete') || stateStr.contains('completed')) {
          print(
            '✅ ICE GATHERING COMPLETE: All ICE candidates have been gathered',
          );
          // You can now safely proceed with any actions that depend on ICE gathering completion
        } else if (stateStr.contains('gathering')) {
          print('🔄 ICE GATHERING IN PROGRESS: Collecting ICE candidates...');
        } else if (stateStr.contains('new')) {
          print('🆕 ICE GATHERING: New state, gathering not started');
        } else {
          print('ℹ️  ICE GATHERING: Unknown state - $state');
        }
        print('❄️ ===================================\n');
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('🔌 Estado de conexión: $state');
      };

      // Añadir tracks del stream local a la conexión
      if (_localStream != null) {
        print('4. Añadiendo tracks locales a la conexión...');
        for (final track in _localStream!.getTracks()) {
          try {
            print('   - Añadiendo track: ${track.kind} (${track.id})');
            await _peerConnection!.addTrack(track, _localStream!);
            print('   - Track ${track.kind} añadido exitosamente');
          } catch (e) {
            print('❌ Error al añadir track ${track.kind}: $e');
            // Continuar con los demás tracks
          }
        }
      } else {
        print('⚠️ No hay stream local para añadir a la conexión');
      }
    } catch (e) {
      print('❌ Error al crear la conexión PeerConnection: $e');
      rethrow;
    }
  }

  // Get list of available cameras
  Future<List<MediaDeviceInfo>> getAvailableCameras() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    _availableCameras = devices
        .where((device) => device.kind == 'videoinput')
        .toList();
    print('${_availableCameras.length} cámaras disponibles:');
    for (var i = 0; i < _availableCameras.length; i++) {
      final camera = _availableCameras[i];
      print('  $i: ${camera.label} (${camera.deviceId})');
    }
    return _availableCameras;
  }

  /// Switch to a specific camera by index
  ///
  /// [cameraIndex] The index of the camera to switch to
  ///
  /// Throws an [ArgumentError] if the index is invalid
  Future<void> switchCamera(int cameraIndex) async {
    if (cameraIndex < 0 || cameraIndex >= _availableCameras.length) {
      final error =
          'Índice de cámara inválido: $cameraIndex. Rango válido: 0-${_availableCameras.length - 1}';
      print('❌ $error');
      throw ArgumentError(error);
    }

    _currentCameraIndex = cameraIndex;

    print(
      '🔄 Cambiando a cámara: ${_availableCameras[_currentCameraIndex].label} '
      '(Frontal: ${isFrontCamera ? 'Sí' : 'No'})',
    );

    // Stop current stream
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
    }

    // Start with new camera
    await startStreaming();
  }

  /// Toggle between available cameras
  ///
  /// This will cycle through all available cameras on the device.
  /// If there's only one camera, this method does nothing.
  Future<void> toggleCamera() async {
    if (_availableCameras.length < 2) {
      print('⚠️ No hay suficientes cámaras para cambiar');
      return;
    }

    // Switch to the next camera
    await switchCamera(_currentCameraIndex);
  }

  Future<void> startStreaming() async {
    if (_isDisposed) {
      throw StateError('WebRTCService has been disposed');
    }

    try {
      // Verificar si ya hay un stream activo
      if (_localStream != null) {
        debugPrint('⚠️ Ya hay un stream activo. Deteniendo stream anterior...');
        await _localStream!.dispose();
        _localStream = null;
      }

      // Obtener cámaras disponibles si no se han obtenido
      if (_availableCameras.isEmpty) {
        await getAvailableCameras();
      }

      // Si no hay cámaras disponibles, lanzar error
      if (_availableCameras.isEmpty) {
        throw StateError('No se encontraron cámaras disponibles');
      }

      // Default to rear camera if available
      if (_availableCameras.length > 1 && _currentCameraIndex == 0) {
        // Try to find rear camera
        final rearCameraIndex = _availableCameras.indexWhere(
          (camera) =>
              camera.label.toLowerCase().contains('back') ||
              camera.label.toLowerCase().contains('rear') ||
              camera.label.toLowerCase().contains('trasera'),
        );

        if (rearCameraIndex != -1) {
          _currentCameraIndex = rearCameraIndex;
        }
      }

      // Configure camera constraints
      final Map<String, dynamic> mediaConstraints = {
        'audio': false,
        'video': {
          'deviceId': _availableCameras[_currentCameraIndex].deviceId,
          'width': {'min': 640, 'ideal': 1280},
          'height': {'min': 480, 'ideal': 720},
          'frameRate': {'min': 15, 'ideal': 30},
        },
      };

      print(
        '📷 Usando cámara: ${_availableCameras[_currentCameraIndex].label}',
      );
      print('🔍 Intentando con restricciones: $mediaConstraints');

      // Intentar obtener el stream con las restricciones
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );

      if (_localStream == null) {
        throw Exception('No se pudo obtener acceso a la cámara: stream nulo');
      }

      print('✅ Stream de cámara obtenido con éxito');
      print('   - Tracks de video: ${_localStream!.getVideoTracks().length}');
      print('   - Tracks de audio: ${_localStream!.getAudioTracks().length}');

      // Verificar si hay tracks de video
      if (_localStream!.getVideoTracks().isEmpty) {
        throw Exception('No se encontraron tracks de video en el stream');
      }

      // Verificar el estado del track de video
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isEmpty) {
        throw Exception('No se encontraron tracks de video en el stream');
      }

      final videoTrack = videoTracks.first;
      print('   - Track ID: ${videoTrack.id}');
      print('   - Habilitado: ${videoTrack.enabled}');
      print('   - Muted: ${videoTrack.muted}');
      print(
        '   - Estado: ${videoTrack.enabled ? 'Habilitado' : 'Deshabilitado'}',
      );

      // Crear la conexión peer
      await _createPeerConnection();

      // Asegurarse de que el stream aún sea válido
      if (_localStream == null) {
        throw Exception('El stream se perdió antes de crear la oferta');
      }

      // Crear y enviar la oferta
      await _createAndSendOffer();
    } catch (e) {
      print('❌ ERROR en startStreaming: $e');
      rethrow;
    }
  }

  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null) return;

    try {
      print('5. Creando oferta...');
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      print('✅ PC: LocalDescription (oferta) establecida.');

      print('-> LOCAL: Enviando oferta al par remoto...');
      _socket!.emit('offer', {
        'sdp': offer.sdp,
        'type': offer.type,
        'roomId': _roomId,
      });
    } catch (e) {
      print('❌ ERROR al crear/enviar la oferta: $e');
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    
    debugPrint('🔌 Cerrando conexiones WebRTC...');
    
    try {
      // Stop all tracks in the local stream
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          try {
            await track.stop();
          } catch (e) {
            debugPrint('❌ Error al detener track: $e');
          }
        }
        await _localStream?.dispose();
        _localStream = null;
      }
      
      // Close peer connection
      if (_peerConnection != null) {
        try {
          _peerConnection!.onIceCandidate = null;
          _peerConnection!.onIceConnectionState = null;
          _peerConnection!.onTrack = null;
          await _peerConnection!.close();
        } catch (e) {
          debugPrint('❌ Error al cerrar la conexión PeerConnection: $e');
        } finally {
          _peerConnection = null;
        }
      }
      
      // Close socket connection
      if (_socket != null) {
        try {
          _socket!.clearListeners();
          _socket!.disconnect();
          _socket!.dispose();
        } catch (e) {
          debugPrint('❌ Error al cerrar el socket: $e');
        } finally {
          _socket = null;
        }
      }
      
      if (!_signalingReadyCompleter.isCompleted) {
        _signalingReadyCompleter.completeError(
          StateError('WebRTCService was disposed before initialization completed'),
        );
      }
      
      debugPrint('✅ Conexiones WebRTC cerradas correctamente');
    } catch (e) {
      debugPrint('❌ Error durante la limpieza de WebRTC: $e');
      rethrow;
    }
  }
}
