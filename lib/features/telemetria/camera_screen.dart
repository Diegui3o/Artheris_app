import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import '../../core/camera/camera_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isDisposed = false;
  bool _isInitializing = false;
  bool _isSwitchingCamera = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_isDisposed || _isInitializing) return;
    
    setState(() => _isInitializing = true);
    final cameraService = Provider.of<CameraService>(context, listen: false);
    
    try {
      await cameraService.initialize();
      // If we have cameras but none is selected, turn on the first one
      if (cameraService.cameras != null && 
          cameraService.cameras!.isNotEmpty && 
          !cameraService.isOn) {
        await cameraService.turnOn();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar la cámara: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _handleSwitchCamera() async {
    if (_isSwitchingCamera) return;
    
    setState(() => _isSwitchingCamera = true);
    final cameraService = Provider.of<CameraService>(context, listen: false);
    
    try {
      await cameraService.switchCamera();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar de cámara: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitchingCamera = false);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) return const SizedBox.shrink();
    
    final cameraService = Provider.of<CameraService>(context);
    final controller = cameraService.controller;
    
    // Show loading indicator while camera is initializing or switching
    if (_isInitializing || _isSwitchingCamera || 
        (cameraService.isOn && (controller == null || !controller.value.isInitialized))) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              const SizedBox(height: 16),
              Text(
                _isSwitchingCamera ? 'Cambiando de cámara...' : 'Inicializando cámara...',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show error message if there's an error
    if (cameraService.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            cameraService.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.red),
          ),
        ),
      );
    }
    
    // Show a message if running on emulator
    if (cameraService.isEmulator) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                const SizedBox(height: 24),
                const Text(
                  'Camera functionality is not available in the emulator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please use a physical device to test camera features.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  onPressed: _initializeCamera,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!cameraService.isOn || cameraService.controller == null) {
      if (cameraService.cameras != null && cameraService.cameras!.isEmpty) {
        return const Center(child: Text('No se encontraron cámaras disponibles'));
      }
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 64, color: Colors.white70),
              const SizedBox(height: 20),
              const Text(
                'Cámara apagada',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.videocam),
                label: const Text('Encender Cámara'),
                onPressed: () async {
                  await cameraService.turnOn();
                  if (mounted) setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!cameraService.controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check if the current camera is front
    final isFront = cameraService.controller!.description.lensDirection == CameraLensDirection.front;
    
    return Stack(
      children: [
        // Mirror the camera preview if it's front
        isFront
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: CameraPreview(cameraService.controller!),
              )
            : CameraPreview(cameraService.controller!),
        // Camera controls overlay
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Toggle Camera Button
              FloatingActionButton(
                heroTag: 'toggle_camera',
                onPressed: () async {
                  if (cameraService.isOn) {
                    await cameraService.turnOff();
                  } else {
                    await cameraService.turnOn();
                  }
                  if (mounted) setState(() {});
                },
                backgroundColor: Colors.black54,
                child: Icon(
                  cameraService.isOn ? Icons.videocam_off : Icons.videocam,
                  color: Colors.white,
                ),
              ),
              
              // Switch Camera Button (only show if multiple cameras available)
              if (cameraService.cameras != null && cameraService.cameras!.length > 1)
                FloatingActionButton(
                  heroTag: 'switch_camera',
                  onPressed: _isSwitchingCamera ? null : _handleSwitchCamera,
                  backgroundColor: Colors.black54,
                  child: _isSwitchingCamera
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.switch_camera, color: Colors.white),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
