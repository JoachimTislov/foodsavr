import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../constants/material3_config.dart';
import '../service_locator.dart';
import '../services/barcode_scanner_service.dart';
import '../services/camera_permission_service.dart';
import '../services/expiry_scanner_service.dart';
import '../utils/expiry_date_picker.dart';
import '../widgets/product/camera_blocked_view.dart';

/// Camera view that OCR-scans a printed expiry date and pops with the
/// recognized or manually picked [DateTime], or null if the user backs out.
class ExpiryScanView extends StatefulWidget {
  const ExpiryScanView({super.key});

  /// Pushes the scanner above the whole app and returns the captured date.
  static Future<DateTime?> show(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push<DateTime>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => const ExpiryScanView(),
        ),
      );

  @override
  State<ExpiryScanView> createState() => _ExpiryScanViewState();
}

class _ExpiryScanViewState extends State<ExpiryScanView>
    with WidgetsBindingObserver {
  late final CameraPermissionService _access =
      CameraPermissionService.resolve();
  CameraController? _cameraController;
  ExpiryScannerService? _expiryScannerService;

  /// Drops the outcome of a camera start that a newer one replaced.
  int _revision = 0;
  bool _isProcessingFrame = false;
  bool _suspended = false;

  /// While the date picker is open, recognized frames are ignored.
  bool _picking = false;
  bool _finished = false;
  CameraAccessStatus? _failure;
  bool _readingFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revision++;
    _cameraController?.dispose();
    _expiryScannerService?.close();
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
    final camera = _cameraController;
    final manualLabel = 'product.enterExpiryManually'.tr();
    final Widget body;
    if (_failure case final failure?) {
      body = CameraBlockedView(
        status: failure,
        onRetry: _retry,
        onEnable: _enableAndRetry,
        onFallback: _pickManually,
        fallbackLabel: manualLabel,
      );
    } else if (_readingFailed || camera == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(Material3Config.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_readingFailed) ...[
                Text(
                  'product.expiryScanUnavailable'.tr(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Material3Config.spacing16),
                FilledButton(
                  onPressed: _startCamera,
                  child: Text('common.tryAgain'.tr()),
                ),
              ] else
                const CircularProgressIndicator(),
              const SizedBox(height: Material3Config.spacing16),
              OutlinedButton.icon(
                onPressed: _pickManually,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(manualLabel),
              ),
            ],
          ),
        ),
      );
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(camera),
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
              onPressed: _pickManually,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(manualLabel),
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
      body: SafeArea(child: body),
    );
  }

  Future<void> _pickManually() async {
    _picking = true;
    final date = await pickExpiryDate(context);
    _picking = false;
    if (date != null && mounted) _finish(date);
  }

  void _finish(DateTime date) {
    if (_finished) return;
    _finished = true;
    Navigator.of(context).pop(date);
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
      debugPrint('Could not release the expiry camera: $error');
    }
  }

  Future<void> _startCamera() async {
    await _tearDownCamera();
    if (!mounted) return;
    final revision = _revision;
    bool isStale() => !mounted || revision != _revision;
    setState(() {
      _failure = null;
      _readingFailed = false;
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
      _expiryScannerService ??= getIt<ExpiryScannerService>();
      await pending.startImageStream(_processCameraImage);
      if (isStale()) return;
      await _access.record(CameraAccessStatus.granted);
      if (isStale()) return;
      setState(() => _cameraController = pending);
      pending = null;
    } catch (error) {
      debugPrint('Could not start the expiry camera: $error');
      final status = CameraPermissionService.classifyError(error);
      await _access.record(status);
      if (!isStale()) setState(() => _failure = status);
    } finally {
      await _release(pending);
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || _picking || _finished || !mounted) return;
    final cameraController = _cameraController;
    final scanner = _expiryScannerService;
    if (cameraController == null ||
        scanner == null ||
        !cameraController.value.isInitialized) {
      return;
    }

    final inputImage = _toInputImage(image, cameraController.description);
    if (inputImage == null) return;
    _isProcessingFrame = true;
    try {
      final DateTime? date;
      try {
        date = await scanner.scanExpiryDate(inputImage);
      } catch (error) {
        debugPrint('Could not read the expiry date: $error');
        await _tearDownCamera();
        if (mounted) setState(() => _readingFailed = true);
        return;
      }
      // The picker may have opened while the frame was being read.
      if (date == null || _picking || _finished || !mounted) return;
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);
      await cameraController.stopImageStream();
      if (mounted) _finish(date);
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
