import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  io.Socket? _socket;
  String? _roomId;
  final String _serverUrl = 'http://localhost:3002/webrtc';

  void _setupSignaling() {
    _socket!.on('connect', (_) {
      print('Connected to signaling server');
    });

    _socket!.on('offer', (data) async {
      if (_peerConnection == null) return;

      try {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']),
        );
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        _socket!.emit('answer', {
          'sdp': answer.sdp,
          'type': answer.type,
          'roomId': _roomId,
        });
      } catch (e) {
        print('Error handling offer: $e');
      }
    });

    _socket!.on('answer', (data) async {
      if (_peerConnection == null) return;

      try {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']),
        );
      } catch (e) {
        print('Error handling answer: $e');
      }
    });

    _socket!.on('candidate', (data) async {
      if (_peerConnection == null) return;

      try {
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ),
        );
      } catch (e) {
        print('Error handling ICE candidate: $e');
      }
    });
  }

  Future<void> initialize() async {
    _socket = io.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _setupSignaling();

    // Connect to the signaling server
    _socket!.connect();
  }

  Future<MediaStream> startCapture() async {
    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': false,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      return _localStream!;
    } catch (e) {
      print('Error accessing camera: $e');
      rethrow;
    }
  }

  Future<void> _createPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate!.isNotEmpty) {
        _socket!.emit('candidate', {
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          'roomId': _roomId,
        });
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state changed: $state');
    };
  }

  Future<void> _addLocalTracks() async {
    if (_localStream == null) return;

    for (final track in _localStream!.getTracks()) {
      await _peerConnection?.addTrack(track, _localStream!);
    }
  }

  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null) return;

    try {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _socket!.emit('offer', {
        'sdp': offer.sdp,
        'type': offer.type,
        'roomId': _roomId,
      });
    } catch (e) {
      print('Error creating/sending offer: $e');
      rethrow;
    }
  }

  Future<void> startStreaming(String roomId) async {
    _roomId = roomId;
    await _createPeerConnection();
    await _addLocalTracks();
    await _createAndSendOffer();
  }

  void stopCapture() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
    _peerConnection?.close();
    _peerConnection = null;
  }

  void dispose() {
    _peerConnection?.close();
    _localStream?.getTracks().forEach((track) => track.stop());
    _socket?.disconnect();
  }
}
