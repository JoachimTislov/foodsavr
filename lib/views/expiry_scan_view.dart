import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../service_locator.dart';
import '../services/expiry_scanner_service.dart';

/// Camera view that OCR-scans a printed expiry date and pops with the
/// recognized [DateTime], or null if the user backs out.
class ExpiryScanView extends StatefulWidget {
  const ExpiryScanView({super.key});

  @override
  State<ExpiryScanView> createState() => _ExpiryScanViewState();
}

class _ExpiryScanViewState extends State<ExpiryScanView>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  late final ExpiryScannerService _expiryScannerService;
  bool _isCameraReady = false;
  bool _isProcessingFrame = false;
  bool _disposed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expiryScannerService = getIt<ExpiryScannerService>();
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _cameraController?.dispose();
    _expiryScannerService.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _tearDownCamera();
    } else if (state == AppLifecycleState.resumed && mounted) {
      _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget body = const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      body = Center(child: Text(_errorMessage!));
    } else if (_isCameraReady && _cameraController != null) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          Positioned(
            bottom: 96,
            left: 24,
            right: 24,
            child: Text(
              'product.scanExpiryHint'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: FilledButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.edit),
              label: Text('product.enterExpiryManually'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('product.scan_expiry'.tr()),
        backgroundColor: colorScheme.surface,
      ),
      body: body,
    );
  }

  Future<void> _tearDownCamera() async {
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    if (!mounted) return;
    setState(() {
      _cameraController = null;
      _isCameraReady = false;
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera available');
      }
      CameraDescription selectedCamera = cameras.first;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }

      final imageFormat = Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21;
      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: imageFormat,
      );

      await controller.initialize();
      await controller.startImageStream(_processCameraImage);
      if (!mounted || _disposed) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'product.scanUnavailable'.tr(
          namedArgs: {'error': '$e'},
        );
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || !mounted) return;
    final cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    final inputImage = _toInputImage(image, cameraController.description);
    if (inputImage == null) return;
    _isProcessingFrame = true;
    try {
      final DateTime? date;
      try {
        date = await _expiryScannerService.scanExpiryDate(inputImage);
      } catch (e) {
        await cameraController.stopImageStream();
        if (!mounted) return;
        setState(() {
          _errorMessage = 'product.scanUnavailable'.tr(
            namedArgs: {'error': '$e'},
          );
        });
        return;
      }
      if (date == null) return;
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);
      await cameraController.stopImageStream();
      if (!mounted) return;
      context.pop(date);
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription description) {
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final inputImageFormat = InputImageFormatValue.fromRawValue(
      image.format.raw,
    );
    if (inputImageFormat == null) return null;
    final sensorRotation = InputImageRotationValue.fromRawValue(
      description.sensorOrientation,
    );
    var rotation = sensorRotation;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final deviceOrientation = _cameraController?.value.deviceOrientation;
      if (deviceOrientation != null) {
        rotation = _compensateAndroidRotation(
          sensorRotation,
          deviceOrientation,
          description.lensDirection,
        );
      }
    }
    if (rotation == null) return null;
    return InputImage.fromBytes(
      bytes: Uint8List.fromList(bytes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: inputImageFormat,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}

InputImageRotation _compensateAndroidRotation(
  InputImageRotation? sensorRotation,
  DeviceOrientation deviceOrientation,
  CameraLensDirection lensDirection,
) {
  final rotation = sensorRotation ?? InputImageRotation.rotation0deg;
  var rotationCompensation = rotation.rawValue;
  switch (deviceOrientation) {
    case DeviceOrientation.portraitUp:
      rotationCompensation = rotation.rawValue;
    case DeviceOrientation.landscapeLeft:
      rotationCompensation = rotation.rawValue + 90;
    case DeviceOrientation.portraitDown:
      rotationCompensation = rotation.rawValue + 180;
    case DeviceOrientation.landscapeRight:
      rotationCompensation = rotation.rawValue + 270;
  }
  var compensation = rotationCompensation % 360;
  if (lensDirection == CameraLensDirection.front) {
    compensation = (360 - compensation) % 360;
  }
  return InputImageRotationValue.fromRawValue(compensation) ??
      InputImageRotation.rotation0deg;
}
