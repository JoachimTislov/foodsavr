import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/open_food_facts_client.dart';
import 'package:foodsavr/utils/product_add_helper.dart';
import 'package:foodsavr/views/batch_expiry_view.dart';
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

  testWidgets('startExpiryFirstFlow opens the batch expiry session', (
    tester,
  ) async {
    await start(tester, ProductAddHelper.startExpiryFirstFlow);

    expect(find.byType(BatchExpiryView), findsOneWidget);
    expect(harness.repository.writes, 0);
  });
}
