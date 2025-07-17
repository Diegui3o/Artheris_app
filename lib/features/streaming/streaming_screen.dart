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
  bool _isFrontCamera = false;
  String _status = 'Inicializando...';
  bool _isSwitchingCamera = false;
  List<MediaDeviceInfo> _availableCameras = [];

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
      _availableCameras = [];
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
          // Get available cameras
          try {
            _availableCameras = await _webRTCService.getAvailableCameras();
            // Check if current camera is front-facing
            if (_availableCameras.isNotEmpty) {
              _isFrontCamera = _availableCameras[_webRTCService.currentCameraIndex].label.toLowerCase().contains('front');
            }
          } catch (e) {
            print('Error getting cameras: $e');
          }
          
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

  Future<void> _toggleCamera() async {
    if (_isSwitchingCamera || !_isStreaming || _availableCameras.length < 2) return;

    setState(() {
      _isSwitchingCamera = true;
      _status = 'Cambiando de cámara...';
    });

    try {
      await _webRTCService.toggleCamera();
      
      // Update camera state
      if (_availableCameras.isNotEmpty) {
        _isFrontCamera = _availableCameras[_webRTCService.currentCameraIndex].label.toLowerCase().contains('front');
      }
      
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = _webRTCService.localStream;
          _status = 'Transmisión activa';
        });
      }
    } catch (e) {
      print('Error al cambiar de cámara: $e');
      if (mounted) {
        setState(() {
          _status = 'Error al cambiar de cámara';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _stopStreaming();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaming en Vivo'),
        backgroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Vista previa de la cámara
          Positioned.fill(
            child: _localRenderer.srcObject == null
                ? Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_off, size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          const Text(
                            'Cámara no disponible',
                            style: TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  )
                : RTCVideoView(
                    _localRenderer,
                    mirror: _isFrontCamera,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),
          
          // Overlay para controles
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Controles de grabación y cámara
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Botón para cambiar de cámara
                      if (_isStreaming && _availableCameras.length > 1)
                        FloatingActionButton(
                          onPressed: _isSwitchingCamera ? null : _toggleCamera,
                          backgroundColor: Colors.white24,
                          elevation: 2,
                          heroTag: 'switch_camera',  
                          child: Icon(
                            Icons.switch_camera,
                            color: Colors.white,
                            size: 28,
                          ),
                        )
                      else
                        const SizedBox(width: 56), 
                      
                      // Botón de inicio/detención
                      FloatingActionButton(
                        onPressed: _isStreaming ? _stopStreaming : _startStreaming,
                        backgroundColor: _isStreaming ? Colors.red : Colors.redAccent,
                        elevation: 4,
                        heroTag: 'start_stop',  
                        child: Icon(
                          _isStreaming ? Icons.stop : Icons.videocam,
                          size: 32,
                        ),
                      ),
                      
                      // Espaciado para mantener la alineación
                      if (_isStreaming && _availableCameras.length > 1)
                        const SizedBox(width: 56)
                      else if (!_isStreaming)
                        const SizedBox(width: 56),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Indicador de carga al cambiar de cámara
          if (_isSwitchingCamera)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Cambiando cámara...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
