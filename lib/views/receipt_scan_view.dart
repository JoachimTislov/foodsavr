import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logger/logger.dart';
import 'package:receipt_recognition/receipt_recognition.dart';

import '../constants/material3_config.dart';
import '../controllers/preferences_controller.dart';
import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/barcode_scanner_service.dart';
import '../services/camera_permission_service.dart';
import '../services/collection_service.dart';
import '../services/receipt_ingestion_service.dart';
import '../utils/collection_types.dart';
import '../widgets/product/camera_blocked_view.dart';
import 'product_form_view.dart';

/// Camera view that scans a supermarket receipt, then ingests the
/// recognized line items as products in a chosen inventory.
class ReceiptScanView extends StatefulWidget {
  const ReceiptScanView({super.key, required this.userId, this.collectionId});

  final String userId;

  /// Inventory the scan was started from; null picks the default inventory.
  final String? collectionId;

  @override
  State<ReceiptScanView> createState() => _ReceiptScanViewState();
}

class _ReceiptScanViewState extends State<ReceiptScanView>
    with WidgetsBindingObserver {
  late final CameraPermissionService _access =
      CameraPermissionService.resolve();
  CameraController? _cameraController;
  ReceiptRecognizer? _recognizer;
  RecognizedScanProgress? _progress;

  /// Drops the outcome of a camera start that a newer one replaced.
  int _revision = 0;
  bool _isProcessingFrame = false;
  bool _isIngesting = false;
  bool _suspended = false;
  CameraAccessStatus? _failure;
  String? _errorMessage;
  List<Collection> _inventories = const [];
  String? _targetId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
    _loadInventories();
  }

  Future<void> _loadInventories() async {
    try {
      final inventories = await getIt<CollectionService>()
          .getCollectionsForUser(widget.userId, type: CollectionType.inventory);
      final target =
          widget.collectionId ??
          await getIt<PreferencesController>().resolveDefaultInventoryId(
            userId: widget.userId,
          );
      if (!mounted) return;
      setState(() {
        _inventories = inventories;
        _targetId = inventories.any((c) => c.id == target) ? target : null;
      });
    } catch (e) {
      // The service falls back to the default inventory when none is picked.
      getIt<Logger>().w('Failed to load inventories for receipt scan: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revision++;
    _cameraController?.dispose();
    _recognizer?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A camera that is still starting is left alone: the permission prompt
    // itself makes the app inactive.
    if (state != AppLifecycleState.resumed) {
      if (_cameraController == null) return;
      _suspended = true;
      _tearDownCamera();
    } else if (_suspended) {
      _suspended = false;
      _startCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget body = const Center(child: CircularProgressIndicator());
    if (_failure case final failure?) {
      body = CameraBlockedView(
        status: failure,
        onRetry: _retry,
        onEnable: _enableAndRetry,
        onFallback: _addManually,
        fallbackLabel: 'receipt.addManually'.tr(),
      );
    } else if (_errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(Material3Config.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: Material3Config.spacing16),
              FilledButton(
                onPressed: _startCamera,
                child: Text('common.tryAgain'.tr()),
              ),
              const SizedBox(height: Material3Config.spacing8),
              TextButton(
                onPressed: _addManually,
                child: Text('receipt.addManually'.tr()),
              ),
            ],
          ),
        ),
      );
    } else if (_cameraController != null) {
      final matchPercentage = _progress?.validationResult.matchPercentage ?? 0;
      final mergedReceipt = _progress?.mergedReceipt;
      final positions = mergedReceipt?.positions ?? [];
      final canIngest =
          !_isIngesting && mergedReceipt != null && mergedReceipt.isConfirmed;
      body = Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          if (_inventories.isNotEmpty)
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: Text('receipt.targetInventory'.tr()),
                  value: _targetId,
                  items: [
                    for (final inventory in _inventories)
                      DropdownMenuItem(
                        value: inventory.id,
                        child: Text(inventory.name),
                      ),
                  ],
                  onChanged: _isIngesting
                      ? null
                      : (id) => setState(() => _targetId = id),
                ),
              ),
            ),
          Positioned(
            bottom: 160,
            left: 24,
            right: 24,
            child: Text(
              'receipt.scanHint'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            bottom: 108,
            left: 24,
            right: 24,
            child: Text(
              'receipt.progress'.tr(
                namedArgs: {
                  'percent': '$matchPercentage',
                  'items': '${positions.length}',
                },
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: FilledButton.icon(
              onPressed: canIngest ? () => _ingest(mergedReceipt) : null,
              icon: _isIngesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text('receipt.addItems'.tr()),
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
        title: Text('receipt.scanTitle'.tr()),
        backgroundColor: colorScheme.surface,
      ),
      body: SafeArea(child: body),
    );
  }

  Future<void> _ingest(RecognizedReceipt receipt) async {
    setState(() => _isIngesting = true);
    final ingestion = getIt<ReceiptIngestionService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ingestion.ingestReceiptDetailed(
        receipt,
        widget.userId,
        collectionId: _targetId,
      );
      if (!result.alreadyAdded &&
          result.savedProducts.isEmpty &&
          receipt.positions.isNotEmpty) {
        throw StateError(
          'Failed to save all ${receipt.positions.length} receipt items',
        );
      }
      if (!mounted) return;
      HapticFeedback.vibrate();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyAdded
                ? 'receipt.alreadyAdded'.tr()
                : 'receipt.added'.tr(
                    namedArgs: {'count': '${result.savedProducts.length}'},
                  ),
          ),
        ),
      );
      Navigator.of(context).pop(!result.alreadyAdded);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isIngesting = false;
        _errorMessage = 'receipt.ingestError'.tr(namedArgs: {'error': '$e'});
      });
    }
  }

  /// Continues without the camera; a saved product closes the scanner.
  Future<void> _addManually() async {
    final added = await ProductFormView.show(context, collectionId: _targetId);
    if (added == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _retry() async {
    BarcodeScannerService.refreshCameraDetection();
    if (BarcodeScannerService.supportsCameraScanning) return _startCamera();
    final blocker = await _access.scanBlocker(ask: true);
    if (mounted) setState(() => _failure = blocker);
  }

  Future<void> _enableAndRetry() async {
    await _access.enable();
    if (mounted) await _retry();
  }

  Future<void> _tearDownCamera() async {
    _revision++;
    final controller = _cameraController;
    if (controller == null) return;
    _cameraController = null;
    if (mounted) setState(() {});
    await _release(controller);
  }

  Future<void> _release(CameraController? controller) async {
    if (controller == null) return;
    try {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } finally {
        await controller.dispose();
      }
    } catch (error) {
      debugPrint('Could not release the receipt camera: $error');
    }
  }

  Future<void> _startCamera() async {
    await _tearDownCamera();
    if (!mounted) return;
    final revision = _revision;
    bool isStale() => !mounted || revision != _revision;
    setState(() {
      _failure = null;
      _errorMessage = null;
    });

    CameraController? pending;
    try {
      if (!await _access.isEnabled() ||
          !BarcodeScannerService.supportsCameraScanning) {
        final blocker = await _access.scanBlocker();
        if (!isStale()) setState(() => _failure = blocker);
        return;
      }
      final camera = await BarcodeScannerService.findCamera();
      if (isStale()) return;
      if (camera == null) {
        setState(() => _failure = CameraAccessStatus.noCamera);
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
      if (isStale()) return;
      _recognizer ??= ReceiptRecognizer(
        onScanUpdate: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      await pending.startImageStream(_processCameraImage);
      if (isStale()) return;
      await _access.record(CameraAccessStatus.granted);
      if (isStale()) return;
      setState(() => _cameraController = pending);
      pending = null;
    } catch (error) {
      debugPrint('Could not start the receipt camera: $error');
      final status = CameraPermissionService.classifyError(error);
      await _access.record(status);
      if (!isStale()) setState(() => _failure = status);
    } finally {
      await _release(pending);
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || !mounted) return;
    final cameraController = _cameraController;
    final recognizer = _recognizer;
    if (cameraController == null ||
        recognizer == null ||
        !cameraController.value.isInitialized) {
      return;
    }

    final inputImage = _toInputImage(image, cameraController.description);
    if (inputImage == null) return;
    _isProcessingFrame = true;
    try {
      await recognizer.processImage(inputImage);
    } catch (e) {
      await cameraController.stopImageStream();
      if (!mounted) return;
      setState(() {
        _errorMessage = 'receipt.ingestError'.tr(namedArgs: {'error': '$e'});
      });
      return;
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
    if (sensorRotation == null) return null;
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
  InputImageRotation sensorRotation,
  DeviceOrientation deviceOrientation,
  CameraLensDirection lensDirection,
) {
  var rotationCompensation = sensorRotation.rawValue;
  switch (deviceOrientation) {
    case DeviceOrientation.portraitUp:
      rotationCompensation = sensorRotation.rawValue;
    case DeviceOrientation.landscapeLeft:
      rotationCompensation = sensorRotation.rawValue + 90;
    case DeviceOrientation.portraitDown:
      rotationCompensation = sensorRotation.rawValue + 180;
    case DeviceOrientation.landscapeRight:
      rotationCompensation = sensorRotation.rawValue + 270;
  }
  var compensation = rotationCompensation % 360;
  if (lensDirection == CameraLensDirection.front) {
    compensation = (360 - compensation) % 360;
  }
  return InputImageRotationValue.fromRawValue(compensation) ??
      InputImageRotation.rotation0deg;
}
