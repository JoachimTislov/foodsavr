import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../widgets/product/barcode_scanner_overlay.dart';

class BarcodeScanView extends StatefulWidget {
  const BarcodeScanView({super.key});

  @override
  State<BarcodeScanView> createState() => _BarcodeScanViewState();
}

class _BarcodeScanViewState extends State<BarcodeScanView>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  bool _isCameraReady = false;
  bool _isProcessingFrame = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraController?.stopImageStream();
      _cameraController?.dispose();
      _cameraController = null;
      _isCameraReady = false;
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
          const BarcodeScannerOverlay(),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Text(
              'product.scanBarcodeHint'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
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
      ),
      body: body,
    );
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
      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isEmpty) return;
      final scannedValue = barcodes.first.rawValue;
      if (scannedValue == null || scannedValue.isEmpty) return;
      await cameraController.stopImageStream();
      if (!mounted) return;
      context.pop(scannedValue);
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _toInputImage(
    CameraImage image,
    CameraDescription description,
  ) {
    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;
    final bytes = plane.bytes;
    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
    if (inputImageFormat == null) return null;

    final rotation =
        InputImageRotationValue.fromRawValue(description.sensorOrientation);
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
