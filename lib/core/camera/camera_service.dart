import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';

// Removed unused _isXiaomiDevice function as we're now using a different resolution strategy

class CameraService {
  static const MethodChannel _maliLoggingChannel = MethodChannel('com.example.pri_app/mali_logging');
  bool _isEmulator = false;
  bool get isEmulator => _isEmulator;
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int? _selectedCameraIndex;
  bool _isOn = false;
  String? _error;

  bool get isOn => _isOn;
  String? get error => _error;
  List<CameraDescription>? get cameras => _cameras;

  CameraService() {
    _isEmulator = !Platform.isAndroid && !Platform.isIOS;
    _configureMaliLogging();
  }

  Future<void> _configureMaliLogging() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _maliLoggingChannel.invokeMethod('setMaliLoggingLevel');
    } catch (e) {
      // Ignore if the platform doesn't support this
      developer.log('Failed to configure Mali logging: $e', name: 'CameraService');
    }
  }

  Future<void> _checkIfEmulator() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _isEmulator = !androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _isEmulator = !iosInfo.isPhysicalDevice;
    }
  }

  Future<void> initialize() async {
    try {
      await _checkIfEmulator();
      if (_isEmulator) {
        _error = 'Camera functionality is not available in the emulator. Please use a physical device for camera testing.';
        return;
      }
      
      // Get the list of available cameras.
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _selectedCameraIndex = 0;
        await _initCameraController(_selectedCameraIndex!);
      }
    } catch (e) {
      _error = 'Error initializing camera: ${e.toString()}';
    }
  }

  // Check if camera is available and ready
  bool isCameraAvailable(int cameraIndex) {
    return _cameras != null && 
           cameraIndex < _cameras!.length &&
           cameraIndex >= 0;
  }

  // Get the first available camera with the given lens direction
  int? findCameraByLensDirection(CameraLensDirection direction) {
    if (_cameras == null || _cameras!.isEmpty) return null;
    
    // First try to find exact match
    for (var i = 0; i < _cameras!.length; i++) {
      if (_cameras![i].lensDirection == direction) {
        return i;
      }
    }
    
    // If no exact match, try to find any camera
    return _cameras!.isNotEmpty ? 0 : null;
  }

  Future<void> _initCameraController(int cameraIndex, {int retryCount = 0}) async {
    if (!isCameraAvailable(cameraIndex)) {
      _error = 'Cámara no disponible';
      _isOn = false;
      return;
    }

    // Start with the lowest resolution and only increase if needed
    ResolutionPreset preset;
    switch (retryCount) {
      case 0:
        preset = ResolutionPreset.low;     // 240p
        break;
      case 1:
        preset = ResolutionPreset.medium;  // 480p
        break;
      default:
        preset = ResolutionPreset.high;    // 720p
    }

    CameraController? newController;
    
    try {
      // Add delay between retries
      if (retryCount > 0) {
        await Future.delayed(Duration(milliseconds: 200 * (retryCount + 1)));
      }

      // Dispose of the previous controller if it exists
      await _safeDisposeController();

      // Create and initialize new controller with timeout
      newController = CameraController(
        _cameras![cameraIndex],
        preset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.unknown,
      );

      try {
        // Initialize with timeout
        await newController.initialize().timeout(
          const Duration(seconds: 5),
        ).catchError((e) {
          if (e is TimeoutException) {
            throw TimeoutException('Camera initialization timed out');
          }
          throw e;
        });

        if (!_isOn) {
          await _safeDisposeController(controller: newController);
          return;
        }

        _controller = newController;
        _error = null;
        developer.log('Camera initialized successfully with resolution: $preset', 
                    name: 'CameraService');
      } catch (e, stackTrace) {
        developer.log('Camera initialization error: $e', name: 'CameraService');
        developer.log('Stack trace: $stackTrace', name: 'CameraService');
        await _safeDisposeController(controller: newController);

        if (retryCount < 2) {
          developer.log('Retrying camera initialization (attempt ${retryCount + 1})', 
                      name: 'CameraService');
          return _initCameraController(cameraIndex, retryCount: retryCount + 1);
        }

        _error = 'Failed to initialize camera: ${e.toString()}';
        _isOn = false;
        _controller = null;
      }
    } catch (e, stackTrace) {
      developer.log('Unexpected error in camera initialization: $e', name: 'CameraService');
      developer.log('Stack trace: $stackTrace', name: 'CameraService');
      await _safeDisposeController(controller: newController);
      
      if (retryCount < 2) {
        return _initCameraController(cameraIndex, retryCount: retryCount + 1);
      }
      
      _error = 'Failed to initialize camera: ${e.toString()}';
      _isOn = false;
      _controller = null;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      _error = 'No se encontró otra cámara';
      return;
    }

    // Find the next available camera
    final currentLensDirection = _cameras![_selectedCameraIndex!].lensDirection;
    CameraLensDirection targetDirection = currentLensDirection == CameraLensDirection.front 
        ? CameraLensDirection.back 
        : CameraLensDirection.front;

    // Find the target camera
    final targetCameraIndex = findCameraByLensDirection(targetDirection);
    if (targetCameraIndex == null || targetCameraIndex == _selectedCameraIndex) {
      // If target camera not found or same as current, just toggle
      _selectedCameraIndex = (_selectedCameraIndex! + 1) % _cameras!.length;
    } else {
      _selectedCameraIndex = targetCameraIndex;
    }

    // Turn off and on to ensure clean state
    await turnOff();
    await Future.delayed(const Duration(milliseconds: 200));
    await turnOn();
  }

  CameraController? get controller => _controller;

  Future<void> _safeDisposeController({CameraController? controller}) async {
    final controllerToDispose = controller ?? _controller;
    if (controllerToDispose == null) return;

    try {
      // Set a timeout for the dispose operation
      await controllerToDispose.dispose().timeout(
        const Duration(seconds: 3),
      ).catchError((e) {
        if (e is TimeoutException) {
          developer.log('Warning: Camera dispose operation timed out', 
                      name: 'CameraService');
          return null;
        }
        throw e; // Re-throw non-timeout errors
      });
    } catch (e) {
      developer.log('Error disposing camera controller: $e', name: 'CameraService');
    } finally {
      if (controller == null) {
        _controller = null;
      }
    }
  }

  Future<void> turnOff() async {
    if (!_isOn) return;
    
    _isOn = false;
    await _safeDisposeController();
  }

  Future<void> turnOn() async {
    if (_isOn) return;
    
    _isOn = true;
    _error = null;

    try {
      // Initialize cameras if needed
      if (_cameras == null || _cameras!.isEmpty) {
        await initialize();
      }

      // If no camera is selected, try to find a suitable one
      if (_selectedCameraIndex == null || !isCameraAvailable(_selectedCameraIndex!)) {
        // Try front camera first
        _selectedCameraIndex = findCameraByLensDirection(CameraLensDirection.front) ??
                             findCameraByLensDirection(CameraLensDirection.back) ??
                             0;
      }

      if (!isCameraAvailable(_selectedCameraIndex!)) {
        _error = 'No se pudo inicializar la cámara';
        _isOn = false;
        return;
      }

      await _initCameraController(_selectedCameraIndex!);
      
      // If initialization failed but we have other cameras, try the next one
      if (_controller == null && _cameras!.length > 1) {
        _selectedCameraIndex = (_selectedCameraIndex! + 1) % _cameras!.length;
        await _initCameraController(_selectedCameraIndex!);
      }
    } catch (e) {
      developer.log('Error turning on camera: $e', name: 'CameraService');
      _isOn = false;
    }
  }

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    try {
      await controller?.dispose();
    } catch (e) {
      // ignore
    }
  }
}
