import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/barcode_scanner_service.dart';
import 'package:foodsavr/services/camera_preference_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    BarcodeScannerService.refreshCameraDetection();
  });

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

  test('hasCamera is false where camera scanning is unsupported', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(await BarcodeScannerService.hasCamera(), isFalse);
    expect(await BarcodeScannerService.hasTextScanner(), isFalse);
  });

  test('the web scanner exists only in browsers', () {
    expect(BarcodeScannerService.supportsWebScanning, kIsWeb);
    expect(
      BarcodeScannerService.supportsLiveScanning,
      BarcodeScannerService.supportsCameraScanning || kIsWeb,
    );
  });

  test('hasCamera follows the camera setting and a refresh', () async {
    const channel = MethodChannel('plugins.flutter.io/camera');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var cameras = <Object>[
      {'name': 'back', 'lensFacing': 'back', 'sensorOrientation': 90},
    ];
    messenger.setMockMethodCallHandler(channel, (_) async => cameras);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(await BarcodeScannerService.hasCamera(), isTrue);

    // The setting applies at once, in both directions.
    await CameraPreferenceService().setEnabled(false);
    expect(await BarcodeScannerService.hasCamera(), isFalse);
    await CameraPreferenceService().setEnabled(true);
    expect(await BarcodeScannerService.hasCamera(), isTrue);

    // The hardware answer is cached until a refresh.
    cameras = [];
    expect(await BarcodeScannerService.hasCamera(), isTrue);
    BarcodeScannerService.refreshCameraDetection();
    expect(await BarcodeScannerService.hasCamera(), isFalse);
  });
}
