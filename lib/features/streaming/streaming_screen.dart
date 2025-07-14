import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pri_app/webrtc/webrtc_service.dart';

class StreamingScreen extends StatefulWidget {
  @override
  StreamingScreenState createState() => StreamingScreenState();
}

class StreamingScreenState extends State<StreamingScreen> {
  late final WebRTCService _webRTCService;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _webRTCService = WebRTCService();
    _initRenderers();
    _webRTCService.initialize();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
  }

  Future<void> _startStreaming() async {
    try {
      final stream = await _webRTCService.startCapture();
      setState(() {
        _localRenderer.srcObject = stream;
        _isStreaming = true;
      });
      await _webRTCService.startStreaming('room1');
    } catch (e) {
      print('Error starting stream: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting stream: $e')));
      }
    }
  }

  Future<void> _stopStreaming() async {
    try {
      _webRTCService.stopCapture();
      setState(() {
        _localRenderer.srcObject = null;
        _isStreaming = false;
      });
    } catch (e) {
      print('Error stopping stream: $e');
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _webRTCService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Streaming en Vivo')),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: RTCVideoView(
                _localRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: _isStreaming ? _stopStreaming : _startStreaming,
        tooltip: _isStreaming ? 'Detener' : 'Iniciar',
        child: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
