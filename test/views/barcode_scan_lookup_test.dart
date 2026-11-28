import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/open_food_facts_client.dart';
import 'package:foodsavr/utils/product_add_helper.dart';
import 'package:foodsavr/views/barcode_scan_view.dart';
import 'package:go_router/go_router.dart';

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

  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  final field = find.byType(TextField);
  final use = find.widgetWithText(FilledButton, 'Use barcode');

  Future<void> open(WidgetTester tester) async {
    harness.useTallWindow(tester);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await context.push<Object>('/barcode-scan');
              },
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/barcode-scan',
          builder: (_, _) => const BarcodeScanView(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpLocalized(tester, null, routerConfig: router);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('unknown barcodes keep the user trying until one is known', (
    tester,
  ) async {
    harness.openFoodFacts.known['4006381333931'] = 'Known product';
    await open(tester);

    await enter(tester, '12');
    expect(find.text('A barcode has 4 to 32 digits.'), findsOneWidget);
    expect(tester.widget<FilledButton>(use).onPressed, isNull);

    await enter(tester, '96385075');
    expect(find.textContaining('check digit does not match'), findsOneWidget);
    expect(tester.widget<FilledButton>(use).onPressed, isNotNull);

    for (final barcode in ['96385075', '4242', '5555', '96385074']) {
      await enter(tester, barcode);
      await press(tester, use);
      expect(find.byType(BarcodeScanView), findsOneWidget);
      expect(find.textContaining('No product found for $barcode'), findsOne);
      expect(find.text('Add product with this barcode'), findsOneWidget);
    }
    expect(result, isNull);
    expect(harness.repository.writes, 0);

    await enter(tester, '4006381 333931');
    expect(find.text('Valid product barcode'), findsOneWidget);
    await press(tester, use);

    expect(result, '4006381333931');
  }, variant: desktop);

  testWidgets('an unknown barcode can be added as the user\'s own', (
    tester,
  ) async {
    await open(tester);
    await enter(tester, '4242');
    await press(tester, use);

    await press(tester, find.text('Add product with this barcode'));

    expect((result as OffProductData).barcode, '4242');
    expect((result as OffProductData).name, isNull);
  }, variant: desktop);

  testWidgets('a name search lists matches that can be picked', (tester) async {
    harness.openFoodFacts.searchable = ['Lettmelk', 'Helmelk'];
    await open(tester);

    await enter(tester, 'melk');
    await press(tester, find.widgetWithText(FilledButton, 'Search'));
    expect(find.text('Brand 0 · 7040000000000'), findsOneWidget);
    await press(tester, find.text('Helmelk'));

    expect((result as OffProductData).name, 'Helmelk');
    expect((result as OffProductData).barcode, '7040000000001');
  }, variant: desktop);

  testWidgets('offline, the barcode goes on to be queued', (tester) async {
    harness.openFoodFacts.offline = true;
    await open(tester);
    await enter(tester, '4242');

    await press(tester, use);

    expect(result, '4242');
  }, variant: desktop);

  testWidgets('offers to start with the expiry date', (tester) async {
    await open(tester);

    await press(tester, find.text('Start with the expiry date'));

    expect(result, BarcodeScanAction.expiryFirst);
  }, variant: desktop);

  testWidgets('a camera turned off in settings can be enabled in place', (
    tester,
  ) async {
    harness.mockDeviceCamera(tester);
    await harness.preference.setEnabled(false);

    await open(tester);
    expect(find.text('Camera access is off'), findsOneWidget);
    expect(harness.cameraCalls, isEmpty);

    await press(tester, find.text('Enable camera'));

    expect(await harness.preference.isEnabled(), isTrue);
    expect(harness.cameraCalls, contains('create'));
    // The device then denies access, which is explained and can be retried.
    expect(find.text('Camera permission denied'), findsOneWidget);
    harness.cameraCalls.clear();
    await press(tester, find.text('Try Again'));
    expect(harness.cameraCalls, contains('create'));
  }, variant: android);

  testWidgets('the card hands over to typing', (tester) async {
    harness.mockDeviceCamera(tester, present: false);
    await open(tester);
    expect(find.text('No camera found'), findsOneWidget);

    await press(tester, find.text('Enter barcode manually'));

    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
  }, variant: android);
}
