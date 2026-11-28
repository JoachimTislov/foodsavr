import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:injectable/injectable.dart';

import '../service_locator.dart';
import 'camera_preference_service.dart';

@injectable
class BarcodeScannerService {
  static bool get supportsCameraScanning =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<CameraDescription?> findCamera() async {
    if (!supportsCameraScanning) return null;

    final cameras = await availableCameras();
    return cameras
            .where((camera) => camera.lensDirection == CameraLensDirection.back)
            .firstOrNull ??
        cameras.firstOrNull;
  }

  static Future<bool>? _hasHardware;

  /// Whether this device can scan with a camera and the user allows it. The
  /// setting is read on every call; the hardware is detected once and cached.
  static Future<bool> hasCamera() async {
    if (!supportsCameraScanning || !await _cameraAllowed()) return false;
    return _hasHardware ??= _detectHardware();
  }

  static Future<bool> _cameraAllowed() async {
    try {
      final preference = getIt.isRegistered<CameraPreferenceService>()
          ? getIt<CameraPreferenceService>()
          : CameraPreferenceService();
      return await preference.isEnabled();
    } catch (error) {
      debugPrint('Could not read the camera setting: $error');
      return true;
    }
  }

  static Future<bool> _detectHardware() async {
    try {
      return await findCamera() != null;
    } catch (_) {
      // A failed detection may succeed later; do not remember it.
      _hasHardware = null;
      return false;
    }
  }

  /// Detects the camera again on the next [hasCamera], for example on a retry.
  static void refreshCameraDetection() => _hasHardware = null;

  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  Future<List<Barcode>> processImage(InputImage inputImage) =>
      _barcodeScanner.processImage(inputImage);

  Future<void> close() => _barcodeScanner.close();
}
