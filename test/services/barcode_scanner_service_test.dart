import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/barcode_scanner_service.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('camera scanning is supported only on Android and iOS', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        BarcodeScannerService.supportsCameraScanning,
        platform == TargetPlatform.android || platform == TargetPlatform.iOS,
        reason: '$platform',
      );
    }
  });
}
