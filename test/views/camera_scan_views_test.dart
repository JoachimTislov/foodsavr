import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/camera_permission_service.dart';
import 'package:foodsavr/views/expiry_scan_view.dart';
import 'package:foodsavr/views/receipt_scan_view.dart';

import '../support/add_product_harness.dart';
import '../support/localized_app.dart';

void main() {
  late AddProductHarness harness;
  Object? result;

  setUpAll(setUpLocalizedApp);
  setUp(() async {
    harness = AddProductHarness();
    await harness.register();
    result = null;
  });
  tearDown(() => getIt.reset());

  // No live scanning here, as in a browser.
  final unsupported = TargetPlatformVariant.only(TargetPlatform.linux);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  Future<void> open(WidgetTester tester, Widget view) async {
    harness.useTallWindow(tester);
    await pumpLocalized(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(
                context,
              ).push<Object>(MaterialPageRoute(builder: (_) => view));
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  final views = <String, Widget Function()>{
    'expiry': () => const ExpiryScanView(),
    'receipt': () => const ReceiptScanView(userId: 'user'),
  };

  for (final MapEntry(key: name, value: view) in views.entries) {
    testWidgets('$name: names the problem and retry asks again', (
      tester,
    ) async {
      harness.camera.current = CameraAccessStatus.insecureContext;

      await open(tester, view());
      expect(find.text('Secure connection required'), findsOneWidget);
      expect(harness.camera.requests, 0);

      harness.camera.answer = CameraAccessStatus.denied;
      await press(tester, 'Try Again');
      expect(find.text('Camera permission denied'), findsOneWidget);

      // Access granted, but this platform still cannot scan: say so.
      harness.camera.answer = CameraAccessStatus.granted;
      await press(tester, 'Try Again');
      expect(find.text('Camera scanning is not available'), findsOneWidget);
      expect(harness.camera.requests, 2);
      expect(tester.takeException(), isNull);
    }, variant: unsupported);

    testWidgets('$name: a camera turned off can be enabled in place', (
      tester,
    ) async {
      await harness.preference.setEnabled(false);

      await open(tester, view());
      expect(find.text('Camera access is off'), findsOneWidget);

      await press(tester, 'Enable camera');

      expect(await harness.preference.isEnabled(), isTrue);
      expect(find.text('Camera scanning is not available'), findsOneWidget);
    }, variant: unsupported);

    testWidgets('$name: a denied device camera can be retried', (tester) async {
      harness.mockDeviceCamera(tester);

      await open(tester, view());
      expect(find.text('Camera permission denied'), findsOneWidget);
      harness.cameraCalls.clear();
      await press(tester, 'Try Again');

      expect(harness.cameraCalls, contains('create'));
      expect(find.text('Camera permission denied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: android);
  }

  testWidgets('expiry: the manual date is returned to the caller', (
    tester,
  ) async {
    await open(tester, const ExpiryScanView());

    await press(tester, 'Enter expiry manually');
    await press(tester, 'OK');

    expect(find.byType(ExpiryScanView), findsNothing);
    expect(result, isA<DateTime>());
  }, variant: unsupported);

  testWidgets('receipt: falls back to adding a product by hand', (
    tester,
  ) async {
    await open(tester, const ReceiptScanView(userId: 'user'));

    await press(tester, 'Add product manually');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product Name'),
      'Milk',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add Product'));
    await tester.pumpAndSettle();

    expect(harness.repository.added.single.name, 'Milk');
    expect(find.byType(ReceiptScanView), findsNothing);
    expect(result, isTrue);
  }, variant: unsupported);
}
