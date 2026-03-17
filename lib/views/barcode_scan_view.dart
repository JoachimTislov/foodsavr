import 'dart:io';

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:watch_it/watch_it.dart';

import '../service_locator.dart';
import '../services/barcode_scanner_service.dart';
import '../widgets/product/barcode_scanner_overlay.dart';

class BarcodeScanView extends StatefulWidget with WatchItStatefulWidgetMixin {
  const BarcodeScanView({super.key});

  @override
  State<BarcodeScanView> createState() => _BarcodeScanViewState();
}

class _BarcodeScanViewState extends State<BarcodeScanView>
    with WidgetsBindingObserver, WatchItMixin {
  CameraController? _cameraController;
  late final BarcodeScannerService _barcodeScannerService;
  final _isCameraReady = ValueNotifier<bool>(false);
  bool _isProcessingFrame = false;
  final _multipleBarcodesDetected = ValueNotifier<bool>(false);
  final _isFlashOn = ValueNotifier<bool>(false);
  final _errorMessage = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _barcodeScannerService = getIt<BarcodeScannerService>();
    _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraReady.value) return;
    try {
      if (_isFlashOn.value) {
        await _cameraController!.setFlashMode(FlashMode.off);
        _isFlashOn.value = false;
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        _isFlashOn.value = true;
      }
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _isCameraReady.dispose();
    _multipleBarcodesDetected.dispose();
    _isFlashOn.dispose();
    _errorMessage.dispose();
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
    final isCameraReady = watch(_isCameraReady).value;
    final multipleBarcodesDetected = watch(_multipleBarcodesDetected).value;
    final isFlashOn = watch(_isFlashOn).value;
    final errorMessage = watch(_errorMessage).value;

    final colorScheme = Theme.of(context).colorScheme;
    Widget body = const Center(child: CircularProgressIndicator());
    if (errorMessage != null) {
      body = Center(child: Text(errorMessage));
    } else if (isCameraReady && _cameraController != null) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          const BarcodeScannerOverlay(),
          Positioned(
            bottom: 96,
            left: 24,
            right: 24,
            child: Text(
              multipleBarcodesDetected
                  ? 'product.scanSingleBarcodeHint'.tr()
                  : 'product.scanBarcodeHint'.tr(),
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
              onPressed: () => context.pop('MANUAL_ENTRY'),
              icon: const Icon(Icons.edit),
              label: Text('product.enterBarcodeManually'.tr()),
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
        title: Text('product.scanBarcode'.tr()),
        backgroundColor: colorScheme.surface,
        actions: [
          if (isCameraReady)
            IconButton(
              icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleFlash,
            ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _tearDownCamera() async {
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    _cameraController = null;
    _isCameraReady.value = false;
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
      if (!mounted) return;
      _cameraController = controller;
      _isCameraReady.value = true;
      _errorMessage.value = null;
    } catch (e) {
      if (!mounted) return;
      _errorMessage.value = 'product.scanUnavailable'.tr(
        namedArgs: {'error': '$e'},
      );
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
      final barcodes = await _barcodeScannerService.processImage(inputImage);
      if (barcodes.length > 1) {
        if (mounted && !_multipleBarcodesDetected.value) {
          _multipleBarcodesDetected.value = true;
        }
        return;
      }
      if (_multipleBarcodesDetected.value && mounted) {
        _multipleBarcodesDetected.value = false;
      }
      if (barcodes.isEmpty) return;
      final scannedValue = barcodes.first.rawValue;
      if (scannedValue == null || scannedValue.isEmpty) return;

      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);

      await cameraController.stopImageStream();
      if (!mounted) return;
      context.pop(scannedValue);
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
