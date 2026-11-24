import 'dart:async';

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../constants/material3_config.dart';
import '../service_locator.dart';
import '../services/barcode_scanner_service.dart';
import '../utils/product_add_helper.dart';
import '../widgets/product/barcode_scanner_overlay.dart';

class BarcodeScanView extends StatefulWidget {
  const BarcodeScanView({super.key});

  @override
  State<BarcodeScanView> createState() => _BarcodeScanViewState();
}

class _BarcodeScanViewState extends State<BarcodeScanView>
    with WidgetsBindingObserver {
  static const _manualFormWidth = 560.0;

  CameraController? _cameraController;
  BarcodeScannerService? _barcodeScannerService;
  Future<void> _cameraTask = Future<void>.value();
  Future<void>? _frameTask;
  int _cameraRevision = 0;
  String _manualBarcode = '';
  bool _cameraLoading = false;
  bool _cameraUnavailable = false;
  bool _manualMode = false;
  bool _multipleBarcodesDetected = false;
  bool _isFlashOn = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    if (BarcodeScannerService.supportsCameraScanning) {
      WidgetsBinding.instance.addObserver(this);
      _updateCamera(start: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateCamera(start: false);
    final scanner = _barcodeScannerService;
    if (scanner != null) {
      unawaited(_closeScanner(scanner));
    }
    super.dispose();
  }

  Future<void> _closeScanner(BarcodeScannerService scanner) async {
    await _frameTask;
    try {
      await scanner.close();
    } catch (error) {
      debugPrint('Could not close barcode scanner: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_manualMode || _submitted || _cameraUnavailable) return;
    setState(() => _updateCamera(start: state == AppLifecycleState.resumed));
  }

  void _updateCamera({required bool start}) {
    final revision = ++_cameraRevision;
    final previous = _cameraController;
    _cameraController = null;
    _cameraLoading = start;
    _isFlashOn = false;
    _multipleBarcodesDetected = false;

    // Finish disposing the previous camera before starting another session.
    _cameraTask = _cameraTask.then((_) async {
      await _disposeCamera(previous);
      if (start && _isCurrentCameraRequest(revision)) {
        await _initializeCamera(revision);
      }
    });
  }

  bool _isCurrentCameraRequest(int revision) =>
      mounted && revision == _cameraRevision && !_submitted;

  Future<void> _disposeCamera(CameraController? camera) async {
    if (camera == null) return;
    try {
      try {
        if (camera.value.isStreamingImages) await camera.stopImageStream();
      } finally {
        await camera.dispose();
      }
    } catch (error) {
      debugPrint('Could not release barcode camera: $error');
    }
  }

  Future<void> _initializeCamera(int revision) async {
    CameraController? pending;
    try {
      final camera = await BarcodeScannerService.findCamera();
      if (!_isCurrentCameraRequest(revision)) return;
      if (camera == null) {
        _showCameraFallback();
        return;
      }

      pending = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );
      await pending.initialize();
      if (!_isCurrentCameraRequest(revision)) return;
      if (!pending.supportsImageStreaming()) {
        _showCameraFallback();
        return;
      }
      _barcodeScannerService ??= getIt<BarcodeScannerService>();
      await pending.startImageStream(_onCameraImage);
      if (!_isCurrentCameraRequest(revision)) return;
      setState(() {
        _cameraController = pending;
        _cameraLoading = false;
      });
      pending = null;
    } catch (error) {
      debugPrint('Could not start barcode camera: $error');
      if (_isCurrentCameraRequest(revision)) _showCameraFallback();
    } finally {
      await _disposeCamera(pending);
    }
  }

  void _showCameraFallback() {
    setState(() {
      _cameraUnavailable = true;
      _updateCamera(start: false);
    });
  }

  Future<void> _toggleFlash() async {
    final camera = _cameraController;
    if (camera == null) return;
    final enableFlash = !_isFlashOn;
    try {
      await camera.setFlashMode(enableFlash ? FlashMode.torch : FlashMode.off);
      if (mounted && identical(camera, _cameraController)) {
        setState(() => _isFlashOn = enableFlash);
      }
    } catch (error) {
      debugPrint('Could not toggle barcode camera flash: $error');
    }
  }

  void _enterManualMode() {
    setState(() {
      _manualMode = true;
      _updateCamera(start: false);
    });
  }

  Future<void> _submit(Object result) async {
    if (_submitted) return;
    _submitted = true;
    if (context.canPop()) {
      context.pop(result);
      return;
    }

    // A direct route has no caller waiting for the barcode.
    _enterManualMode();
    try {
      final added = await ProductAddHelper.finishAddProductFlow(
        context,
        result,
      );
      if (added == true && mounted) context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _submitted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _cameraController;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          camera != null
              ? 'product.scanBarcode'.tr()
              : 'product.enterBarcodeManually'.tr(),
        ),
        actions: [
          if (camera != null)
            IconButton(
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
              tooltip: 'product.toggleScannerFlash'.tr(),
              onPressed: _toggleFlash,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed shares keep the preview visible when the panel is tall
            // (short landscape windows, large text); the panel scrolls.
            if (camera != null)
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(child: CameraPreview(camera)),
                    const BarcodeScannerOverlay(),
                  ],
                ),
              ),
            Expanded(
              flex: camera == null ? 1 : 2,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Material3Config.spacing24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _manualFormWidth,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (camera != null) ...[
                          Text(
                            _multipleBarcodesDetected
                                ? 'product.scanSingleBarcodeHint'.tr()
                                : 'product.scanBarcodeHint'.tr(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Material3Config.spacing16),
                        ],
                        if (_cameraLoading) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: Material3Config.spacing16),
                        ],
                        if (camera != null || _cameraLoading)
                          OutlinedButton.icon(
                            onPressed: _enterManualMode,
                            icon: const Icon(Icons.edit_outlined),
                            label: Text('product.enterBarcodeManually'.tr()),
                          )
                        else ...[
                          if (_cameraUnavailable) ...[
                            Text(
                              'product.scanUnavailable'.tr(),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: Material3Config.spacing16),
                          ],
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'product.barcodeNumber'.tr(),
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onChanged: (value) =>
                                setState(() => _manualBarcode = value.trim()),
                            onSubmitted: (value) {
                              final barcode = value.trim();
                              if (barcode.isNotEmpty) _submit(barcode);
                            },
                          ),
                          const SizedBox(height: Material3Config.spacing16),
                          FilledButton(
                            onPressed: _submitted || _manualBarcode.isEmpty
                                ? null
                                : () => _submit(_manualBarcode),
                            child: Text('product.useBarcode'.tr()),
                          ),
                        ],
                        TextButton(
                          onPressed: _submitted
                              ? null
                              : () => _submit(
                                  BarcodeScanAction.addWithoutBarcode,
                                ),
                          child: Text('product.addWithoutBarcode'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onCameraImage(CameraImage image) {
    final camera = _cameraController;
    if (camera == null || _frameTask != null || !mounted || _submitted) return;
    _frameTask = _processCameraImage(image, camera).whenComplete(() {
      _frameTask = null;
    });
  }

  Future<void> _processCameraImage(
    CameraImage image,
    CameraController camera,
  ) async {
    try {
      final inputImage = _toInputImage(image, camera.description);
      if (inputImage == null) return;

      final barcodes = await _barcodeScannerService!.processImage(inputImage);
      if (!mounted || !identical(camera, _cameraController) || _submitted) {
        return;
      }

      final multipleBarcodes = barcodes.length > 1;
      if (_multipleBarcodesDetected != multipleBarcodes) {
        setState(() => _multipleBarcodesDetected = multipleBarcodes);
      }

      final barcode = barcodes.singleOrNull?.rawValue;
      if (barcode == null || barcode.isEmpty) return;
      unawaited(HapticFeedback.vibrate());
      unawaited(SystemSound.play(SystemSoundType.click));
      await _submit(barcode);
    } catch (error) {
      debugPrint('Could not read barcode camera image: $error');
      if (mounted && identical(camera, _cameraController) && !_submitted) {
        _showCameraFallback();
      }
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

    final rotation = InputImageRotationValue.fromRawValue(
      description.sensorOrientation,
    );
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
