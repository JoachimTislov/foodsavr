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
import '../services/camera_permission_service.dart';
import '../services/open_food_facts_client.dart';
import '../utils/barcode_validator.dart';
import '../utils/product_add_helper.dart';
import '../widgets/product/barcode_scanner_overlay.dart';
import '../widgets/product/camera_permission_card.dart';
import '../widgets/product/product_lookup_panel.dart';

class BarcodeScanView extends StatefulWidget {
  const BarcodeScanView({super.key});

  @override
  State<BarcodeScanView> createState() => _BarcodeScanViewState();
}

class _BarcodeScanViewState extends State<BarcodeScanView>
    with WidgetsBindingObserver {
  static const _manualFormWidth = 560.0;

  late final CameraPermissionService _access =
      CameraPermissionService.resolve();
  final _lookupFocus = FocusNode();
  CameraController? _cameraController;
  BarcodeScannerService? _barcodeScannerService;
  Future<void> _cameraTask = Future<void>.value();
  Future<void>? _frameTask;
  int _cameraRevision = 0;
  bool _cameraLoading = false;
  CameraAccessStatus? _failure;

  /// The barcode the camera read last; it is looked up below the preview.
  String? _scannedBarcode;
  bool _notProductCode = false;
  bool _suspended = false;
  bool _manualMode = false;
  bool _multipleBarcodesDetected = false;
  bool _isFlashOn = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateCamera(start: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateCamera(start: false);
    _lookupFocus.dispose();
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
    if (_manualMode || _submitted) return;
    // A camera that is still starting is left alone: the permission prompt
    // itself makes the app inactive.
    if (state != AppLifecycleState.resumed) {
      if (_cameraController == null) return;
      _suspended = true;
      setState(() => _updateCamera(start: false));
    } else if (_suspended) {
      _suspended = false;
      setState(() => _updateCamera(start: true));
    }
  }

  void _updateCamera({required bool start}) {
    final revision = ++_cameraRevision;
    final previous = _cameraController;
    _cameraController = null;
    _cameraLoading = start && BarcodeScannerService.supportsCameraScanning;
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
      if (!await _access.isEnabled() ||
          !BarcodeScannerService.supportsCameraScanning) {
        final blocker = await _access.scanBlocker();
        if (_isCurrentCameraRequest(revision)) _showCameraFallback(blocker);
        return;
      }
      final camera = await BarcodeScannerService.findCamera();
      if (!_isCurrentCameraRequest(revision)) return;
      if (camera == null) {
        _showCameraFallback(CameraAccessStatus.noCamera);
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
        _showCameraFallback(CameraAccessStatus.unsupported);
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
      await _access.record(CameraAccessStatus.granted);
    } catch (error) {
      debugPrint('Could not start barcode camera: $error');
      final status = CameraPermissionService.classifyError(error);
      await _access.record(status);
      if (_isCurrentCameraRequest(revision)) _showCameraFallback(status);
    } finally {
      await _disposeCamera(pending);
    }
  }

  void _showCameraFallback(CameraAccessStatus status) {
    setState(() {
      _failure = status;
      _updateCamera(start: false);
    });
  }

  Future<void> _retryCamera() async {
    BarcodeScannerService.refreshCameraDetection();
    if (!BarcodeScannerService.supportsCameraScanning) {
      final blocker = await _access.scanBlocker(ask: true);
      if (mounted) setState(() => _failure = blocker);
      return;
    }
    setState(() {
      _failure = null;
      _manualMode = false;
      _scannedBarcode = null;
      _updateCamera(start: true);
    });
  }

  Future<void> _enableAndRetry() async {
    await _access.enable();
    if (mounted) await _retryCamera();
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
      _scannedBarcode = null;
      _notProductCode = false;
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

  /// The lookup for typed input, or for the [scanned] barcode. A barcode that
  /// nobody knows keeps the user here to try again.
  ProductLookupPanel _lookupPanel(String? scanned) => ProductLookupPanel(
    key: ValueKey(scanned),
    initialQuery: scanned,
    focusNode: scanned == null ? _lookupFocus : null,
    barcodeActionLabel: 'product.useBarcode'.tr(),
    keepBarcodeLabel: 'product.lookup.addWithBarcode'.tr(),
    onBarcodeMatched: _submit,
    onCandidate: _submit,
    onKeepBarcode: (barcode) => _submit(OffProductData(barcode: barcode)),
  );

  @override
  Widget build(BuildContext context) {
    final camera = _cameraController;
    final scanned = _scannedBarcode;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          camera != null ? 'product.scanBarcode'.tr() : 'product.add'.tr(),
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
                                : _notProductCode
                                ? 'product.notProductBarcode'.tr()
                                : 'product.scanBarcodeHint'.tr(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Material3Config.spacing16),
                        ],
                        if (_cameraLoading) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: Material3Config.spacing16),
                        ],
                        if (_failure case final failure?) ...[
                          CameraPermissionCard(
                            status: failure,
                            onRetry: _retryCamera,
                            onEnable: _enableAndRetry,
                            onFallback: _lookupFocus.requestFocus,
                            fallbackLabel: 'product.enterBarcodeManually'.tr(),
                          ),
                          const SizedBox(height: Material3Config.spacing16),
                        ],
                        if (camera != null && scanned != null) ...[
                          _lookupPanel(scanned),
                          const SizedBox(height: Material3Config.spacing16),
                        ],
                        if (camera != null || _cameraLoading)
                          OutlinedButton.icon(
                            onPressed: _enterManualMode,
                            icon: const Icon(Icons.edit_outlined),
                            label: Text('product.enterBarcodeManually'.tr()),
                          )
                        else ...[
                          _lookupPanel(null),
                          if (_manualMode &&
                              _failure == null &&
                              BarcodeScannerService.supportsCameraScanning) ...[
                            const SizedBox(height: Material3Config.spacing8),
                            OutlinedButton.icon(
                              onPressed: _submitted ? null : _retryCamera,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: Text('product.scanBarcode'.tr()),
                            ),
                          ],
                        ],
                        TextButton(
                          onPressed: _submitted
                              ? null
                              : () => _submit(
                                  BarcodeScanAction.addWithoutBarcode,
                                ),
                          child: Text('product.addWithoutBarcode'.tr()),
                        ),
                        TextButton.icon(
                          onPressed: _submitted
                              ? null
                              : () => _submit(BarcodeScanAction.expiryFirst),
                          icon: const Icon(Icons.event_outlined),
                          label: Text('product.expiryFirst'.tr()),
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

      final raw = barcodes.singleOrNull?.rawValue;
      if (raw == null || raw.isEmpty) return;
      final code = BarcodeValidator.validate(raw);
      final usable = code.validity != BarcodeValidity.invalidFormat;
      if (_notProductCode == usable) {
        setState(() => _notProductCode = !usable);
      }
      if (!usable || code.barcode == _scannedBarcode) return;
      unawaited(HapticFeedback.vibrate());
      unawaited(SystemSound.play(SystemSoundType.click));
      setState(() => _scannedBarcode = code.barcode);
    } catch (error) {
      debugPrint('Could not read barcode camera image: $error');
      if (mounted && identical(camera, _cameraController) && !_submitted) {
        _showCameraFallback(CameraAccessStatus.inUse);
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
