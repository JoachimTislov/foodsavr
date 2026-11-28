import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/camera_permission_service.dart';
import 'barcode_scanner_overlay.dart';

/// Live barcode preview for browsers, where the camera plugin cannot feed ML
/// Kit. Reports the raw values of each frame and, once, why the camera failed.
class WebBarcodeScanner extends StatefulWidget {
  /// The raw values read from one frame; empty values are skipped.
  final ValueChanged<List<String?>> onBarcodes;
  final ValueChanged<CameraAccessStatus> onError;

  const WebBarcodeScanner({
    super.key,
    required this.onBarcodes,
    required this.onError,
  });

  /// Product code formats; QR and other codes are not products.
  static const formats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.code128,
  ];

  /// The access status behind a scanner failure.
  static CameraAccessStatus statusFor(MobileScannerErrorCode code) =>
      switch (code) {
        MobileScannerErrorCode.permissionDenied => CameraAccessStatus.denied,
        MobileScannerErrorCode.unsupported => CameraAccessStatus.unsupported,
        _ => CameraAccessStatus.inUse,
      };

  @override
  State<WebBarcodeScanner> createState() => _WebBarcodeScannerState();
}

class _WebBarcodeScannerState extends State<WebBarcodeScanner> {
  final _controller = MobileScannerController(
    formats: WebBarcodeScanner.formats,
    facing: CameraFacing.back,
  );
  bool _errorReported = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reportError(MobileScannerException error) {
    if (_errorReported) return;
    _errorReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onError(WebBarcodeScanner.statusFor(error.errorCode));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) => widget.onBarcodes([
            for (final barcode in capture.barcodes) barcode.rawValue,
          ]),
          errorBuilder: (context, error) {
            _reportError(error);
            return const SizedBox.shrink();
          },
        ),
        const BarcodeScannerOverlay(),
      ],
    );
  }
}
