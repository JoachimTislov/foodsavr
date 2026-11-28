import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/views/batch_expiry_view.dart';

import '../support/add_product_harness.dart';
import '../support/localized_app.dart';

void main() {
  late AddProductHarness harness;
  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);

  setUpAll(setUpLocalizedApp);

  setUp(() async {
    harness = AddProductHarness();
    await harness.register();
    harness.repository.products.add(
      const Product(id: 'p1', name: 'Milk', description: '', userId: 'user'),
    );
  });

  testWidgets('an existing product gets an expiry and is listed', (
    tester,
  ) async {
    harness.useTallWindow(tester);
    await pumpLocalized(tester, const BatchExpiryView());

    await tester.enterText(find.byType(TextField), 'mil');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set expiry date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and add next'));
    await tester.pumpAndSettle();

    final stored = harness.repository.updated.single;
    expect(stored.id, 'p1');
    expect(stored.expiries.single.quantity, 2);
    expect(find.text('Registered this session'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Set expiry date'), findsNothing);
  }, variant: desktop);

  testWidgets('a new product is created with the expiry and its inventory', (
    tester,
  ) async {
    harness.useTallWindow(tester);
    await pumpLocalized(tester, const BatchExpiryView(collectionId: 'inv'));

    await tester.enterText(find.byType(TextField), 'Oat drink');
    await tester.pumpAndSettle();
    await tester.tap(find.text('New product «Oat drink»'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set expiry date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and add next'));
    await tester.pumpAndSettle();

    final created = harness.repository.added.single;
    expect(created.name, 'Oat drink');
    expect(created.expiries.single.quantity, 1);
    expect(find.text('Registered this session'), findsOneWidget);
  }, variant: desktop);
}
