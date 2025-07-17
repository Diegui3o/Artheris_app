import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pri_app/webrtc/webrtc_service.dart';

class StreamingScreen extends StatefulWidget {
  @override
  StreamingScreenState createState() => StreamingScreenState();
}

class StreamingScreenState extends State<StreamingScreen> {
  late WebRTCService _webRTCService;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isStreaming = false;
  String _status = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    _initRenderers().catchError((error) {
      setState(() {
        _status = 'Error al inicializar: ${error.toString()}';
      });
    });
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    setState(() {
      _status = 'Listo para transmitir';
    });
  }

  Future<void> _startStreaming() async {
    if (_isStreaming) return;
    
    setState(() {
      _isStreaming = true;
      _status = 'Iniciando transmisión...';
    });

    try {
      _webRTCService = WebRTCService();
      
      // Mostrar un diálogo de carga
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        await _webRTCService.initialize('test-room');
        
        _webRTCService.onIceConnectionStateChange = (state) {
          if (mounted) {
            setState(() {
              _status = 'Estado ICE: ${state.name}';
            });
          }
          
          // Si la conexión falla, detener el streaming
          if (state.toString().contains('failed') || 
              state.toString().contains('disconnected')) {
            _stopStreaming();
          }
        };

        await _webRTCService.startStreaming();
        final localStream = _webRTCService.localStream;
        
        if (mounted) {
          setState(() {
            _localRenderer.srcObject = localStream;
            _status = 'Transmisión activa';
          });
        }
        
      } finally {
        // Cerrar el diálogo de carga
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
      
    } catch (e) {
      print('Error en _startStreaming: $e');
      if (mounted) {
        setState(() {
          _status = 'Error: ${e.toString().split('\n').first}';
          _isStreaming = false;
        });
        _showErrorDialog('Error al iniciar la transmisión', e.toString());
      }
      await _stopStreaming();
    }
  }

  Future<void> _stopStreaming() async {
    if (!_isStreaming) return;
    
    setState(() {
      _isStreaming = false;
      _status = 'Deteniendo transmisión...';
    });
    
    try {
      await _webRTCService.dispose();
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = null;
          _status = 'Transmisión detenida';
        });
      }
    } catch (e) {
      print('Error en _stopStreaming: $e');
      if (mounted) {
        setState(() {
          _status = 'Error al detener: ${e.toString().split('\n').first}';
        });
      }
    }
    
    // Actualizar el estado después de un breve retraso
    if (mounted) {
      Future.delayed(Duration(seconds: 2), () {
        if (mounted && !_isStreaming) {
          setState(() {
            _status = 'Listo para transmitir';
          });
        }
      });
    }
  }
  
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  @override
  void dispose() {
    if (_isStreaming) {
      _stopStreaming().catchError((_) {});
    }
    _localRenderer.srcObject = null;
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transmitir Video'),
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.grey.shade800),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Stack(
                children: [
                  RTCVideoView(_localRenderer, mirror: true),
                  if (_localRenderer.srcObject == null)
                    Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam_off, size: 50, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Esperando video...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              _status,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _isStreaming ? Colors.grey : Colors.red,
        onPressed: _isStreaming ? _stopStreaming : _startStreaming,
        tooltip: _isStreaming ? 'Detener' : 'Iniciar',
        child: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
