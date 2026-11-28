import 'package:camera/camera.dart';

import 'barcode_scanner_service.dart';
import 'camera_permission_service.dart';

/// Camera access outside the browser, where only the camera plugin can ask.
CameraAccessPlatform createCameraAccessPlatform() => _PluginCameraAccess();

class _PluginCameraAccess implements CameraAccessPlatform {
  @override
  Future<CameraAccessStatus?> query() async {
    if (!BarcodeScannerService.supportsCameraScanning) {
      return CameraAccessStatus.unsupported;
    }
    // The plugin cannot read the permission without asking for it.
    return await BarcodeScannerService.findCamera() == null
        ? CameraAccessStatus.noCamera
        : null;
  }

  @override
  Future<CameraAccessStatus> request() async {
    if (!BarcodeScannerService.supportsCameraScanning) {
      return CameraAccessStatus.unsupported;
    }
    final camera = await BarcodeScannerService.findCamera();
    if (camera == null) return CameraAccessStatus.noCamera;
    final probe = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: false,
    );
    try {
      await probe.initialize();
      return CameraAccessStatus.granted;
    } finally {
      await probe.dispose();
    }
  }
}
