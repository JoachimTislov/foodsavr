import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/open_food_facts_client.dart';
import 'package:foodsavr/utils/product_add_helper.dart';
import 'package:foodsavr/views/expiry_scan_view.dart';
import 'package:foodsavr/widgets/product/camera_permission_card.dart';
import 'package:go_router/go_router.dart';

import '../support/add_product_harness.dart';
import '../support/localized_app.dart';

void main() {
  late AddProductHarness harness;

  setUpAll(setUpLocalizedApp);
  setUp(() async {
    harness = AddProductHarness();
    await harness.register();
  });
  tearDown(() => getIt.reset());

  final lookupField = find.widgetWithText(TextField, 'Barcode or product name');
  final addButton = find.widgetWithText(FilledButton, 'Add Product');
  final nameField = find.widgetWithText(TextFormField, 'Product Name');
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  Future<void> start(
    WidgetTester tester,
    Future<Object?> Function(BuildContext context) flow,
  ) async {
    harness.useTallWindow(tester);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => flow(context),
                child: const Text('start'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/barcode-scan',
          builder: (_, _) => const Scaffold(body: Text('scanner')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpLocalized(tester, null, routerConfig: router);
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
  }

  group('startAddProductFlow', () {
    testWidgets('starts with the scanner when a camera can scan', (
      tester,
    ) async {
      harness.mockDeviceCamera(tester);

      await start(tester, ProductAddHelper.startAddProductFlow);

      expect(find.text('scanner'), findsOneWidget);
      expect(lookupField, findsNothing);
    }, variant: android);

    for (final reason in ['no camera', 'camera turned off', 'desktop']) {
      testWidgets(
        'opens the Add Product modal with a lookup: $reason',
        (tester) async {
          harness.mockDeviceCamera(tester, present: reason != 'no camera');
          if (reason == 'camera turned off') {
            await harness.preference.setEnabled(false);
          }

          await start(tester, ProductAddHelper.startAddProductFlow);

          expect(find.text('scanner'), findsNothing);
          expect(lookupField, findsOneWidget);
          expect(addButton, findsOneWidget);
        },
        variant: TargetPlatformVariant.only(
          reason == 'desktop' ? TargetPlatform.linux : TargetPlatform.android,
        ),
      );
    }
  });

  testWidgets('a chosen candidate prefills the form', (tester) async {
    await start(
      tester,
      (context) => ProductAddHelper.finishAddProductFlow(
        context,
        const OffProductData(
          name: 'Lettmelk',
          barcode: '7038010009457',
          tags: ['en:dairies', 'en:milks'],
        ),
      ),
    );

    expect(find.text('Barcode: 7038010009457'), findsOneWidget);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final saved = harness.repository.added.single;
    expect(saved.name, 'Lettmelk');
    expect(saved.barcode, '7038010009457');
    expect(saved.category, 'dairy');
    expect(saved.expiries.single.daysUntilExpiration, 10);
    expect(saved.quantity, 1);
  });

  group('startExpiryFirstFlow', () {
    Future<void> pickDefaultDate(WidgetTester tester) async {
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'without a camera picks a date, then saves it with the details',
      (tester) async {
        await start(tester, ProductAddHelper.startExpiryFirstFlow);
        expect(find.byType(ExpiryScanView), findsNothing);

        await pickDefaultDate(tester);
        await tester.enterText(nameField, 'Yoghurt');
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        final saved = harness.repository.added.single;
        expect(saved.name, 'Yoghurt');
        // The default is just beyond the six day expiring-soon window.
        expect(saved.expiries.single.daysUntilExpiration, 7);
        expect(saved.nonExpiringQuantity, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('cancelling the date adds nothing', (tester) async {
      await start(tester, ProductAddHelper.startExpiryFirstFlow);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(addButton, findsNothing);
      expect(harness.repository.writes, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('the captured date survives a catalog match', (tester) async {
      harness.openFoodFacts
        ..searchable = ['Gresk yoghurt']
        ..tags = ['en:yogurts'];
      await start(tester, ProductAddHelper.startExpiryFirstFlow);
      await pickDefaultDate(tester);

      await tester.enterText(lookupField, 'yoghurt');
      await tester.pump();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gresk yoghurt'));
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      final saved = harness.repository.added.single;
      expect(saved.name, 'Gresk yoghurt');
      expect(saved.expiries.single.daysUntilExpiration, 7);
      expect(saved.quantity, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('the captured date survives a one-tap essential', (
      tester,
    ) async {
      harness.repository.products.add(
        const Product(
          id: 'global-milk',
          name: 'Whole Milk',
          description: '',
          userId: 'system',
          category: 'dairy',
          isGlobal: true,
          registryType: 'global',
        ),
      );
      await start(tester, ProductAddHelper.startExpiryFirstFlow);
      await pickDefaultDate(tester);

      await tester.tap(find.text('Browse essentials'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quick add'));
      await tester.pumpAndSettle();

      final saved = harness.repository.added.single;
      expect(saved.expiries.single.daysUntilExpiration, 7);
      expect(saved.quantity, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('with a camera opens the scanner, never a dead end', (
      tester,
    ) async {
      harness.mockDeviceCamera(tester);

      await start(tester, ProductAddHelper.startExpiryFirstFlow);
      expect(find.byType(ExpiryScanView), findsOneWidget);
      expect(find.byType(CameraPermissionCard), findsOneWidget);
      expect(find.text('Camera permission denied'), findsOneWidget);

      await tester.tap(find.text('Enter expiry manually'));
      await tester.pumpAndSettle();
      await pickDefaultDate(tester);

      expect(find.byType(ExpiryScanView), findsNothing);
      expect(addButton, findsOneWidget);
    }, variant: android);
  });
}
