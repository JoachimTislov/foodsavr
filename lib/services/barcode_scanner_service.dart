import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:injectable/injectable.dart';

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

  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  Future<List<Barcode>> processImage(InputImage inputImage) =>
      _barcodeScanner.processImage(inputImage);

  Future<void> close() => _barcodeScanner.close();
}
