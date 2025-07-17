import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  io.Socket? _socket;
  String? _roomId;
  final String _serverUrl = 'http://192.168.1.11:3002/webrtc';
  final Completer<void> _signalingReadyCompleter = Completer<void>();

  // Callback para cuando la conexión se establece
  Function(RTCIceConnectionState)? onIceConnectionStateChange;

  // Getter para exponer el stream local de forma segura
  MediaStream? get localStream => _localStream;

  Future<void> initialize(String roomId) async {
    _roomId = roomId;
    print('🔄 Conectando a $_serverUrl...');

    _socket = io.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _setupSignaling();

    try {
      _socket!.connect();
      // Agrega timeout
      return _signalingReadyCompleter.future.timeout(
        Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('No se pudo conectar al servidor'),
      );
    } catch (e) {
      print('❌ Error al conectar: $e');
      rethrow;
    }
  }

  void _setupSignaling() {
    _socket!.onConnect((_) {
      print('✅ SIGNAL: Conectado al servidor de señalización!');
      print('2. Uniéndose a la sala: $_roomId');
      _socket!.emit('join', _roomId);
      _socket!.onError((data) => print('❌ ERROR de Socket: $data'));
      _socket!.on('error', (data) => print('❌ ERROR del Servidor: $data'));
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
          print('✅ ICE GATHERING COMPLETE: All ICE candidates have been gathered');
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

  Future<void> startStreaming() async {
    try {
      print('1. Obteniendo video de la cámara...');

      // Primero verifiquemos los dispositivos disponibles
      final devices = await navigator.mediaDevices.enumerateDevices();
      print('Dispositivos multimedia disponibles:');
      for (var device in devices) {
        print(' - ${device.kind}: ${device.label} (${device.deviceId})');
      }

      // Configuración más simple para la cámara
      final Map<String, dynamic> mediaConstraints = {
        'audio': false,
        'video': {
          'facingMode': 'user',
          'width': {'min': 640, 'ideal': 1280},
          'height': {'min': 480, 'ideal': 720},
          'frameRate': {'min': 15, 'ideal': 30},
        },
      };

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
    print('Limpiando recursos...');
    if (_localStream != null) {
      await Future.wait(_localStream!.getTracks().map((track) => track.stop()));
    }
    await _localStream?.dispose();
    await _peerConnection?.close();
    _socket?.disconnect();
    _socket?.dispose();
  }
}
