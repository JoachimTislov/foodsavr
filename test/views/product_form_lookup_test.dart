import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/views/product_form_view.dart';

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

  final field = find.widgetWithText(TextField, 'Barcode or product name');
  final addButton = find.widgetWithText(FilledButton, 'Add Product');
  final nameField = find.widgetWithText(TextFormField, 'Product Name');

  Future<void> open(WidgetTester tester, {Product? product}) async {
    harness.useTallWindow(tester);
    await pumpLocalized(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ProductFormView.show(context, product: product),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(field, query);
    await tester.pump();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
  }

  testWidgets('any number of lookups, then an own barcode is kept', (
    tester,
  ) async {
    await open(tester);

    for (final barcode in ['4242', '5555', '96385074']) {
      await search(tester, barcode);
      expect(find.textContaining('No product found for $barcode'), findsOne);
    }
    await tester.tap(find.text('Use this barcode'));
    await tester.pumpAndSettle();
    expect(find.text('Barcode: 0000096385074'), findsOneWidget);

    await tester.enterText(nameField, 'Own jam');
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Stored as a scan stores it, so a later scan finds the product.
    expect(harness.repository.added.single.barcode, '0000096385074');
  });

  testWidgets('a removed barcode is not saved', (tester) async {
    await open(tester);
    await search(tester, '4242');
    await tester.tap(find.text('Use this barcode'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove barcode'));
    await tester.pumpAndSettle();
    await tester.enterText(nameField, 'Own jam');
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(harness.repository.added.single.barcode, isNull);
  });

  testWidgets('a partial search prefills name, category, barcode, expiry', (
    tester,
  ) async {
    harness.openFoodFacts
      ..searchable = ['Grovbrød', 'Loff']
      ..tags = ['en:breads'];
    await open(tester);

    await search(tester, 'brød');
    expect(find.text('Matches from Open Food Facts'), findsOneWidget);
    await tester.tap(find.text('Grovbrød'));
    await tester.pumpAndSettle();
    expect(find.text('Loff'), findsNothing);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final saved = harness.repository.added.single;
    expect(saved.name, 'Grovbrød');
    expect(saved.category, 'bakery');
    expect(saved.barcode, '7040000000000');
    expect(saved.tags, ['en:breads']);
    expect(saved.expiries.single.daysUntilExpiration, 5);
    expect(saved.quantity, 1);
  });

  testWidgets('being offline is said plainly', (tester) async {
    harness.openFoodFacts.offline = true;
    await open(tester);

    await search(tester, 'melk');

    expect(find.textContaining('could not be reached'), findsOneWidget);
  });

  testWidgets('editing a product offers no lookup', (tester) async {
    await open(
      tester,
      product: const Product(
        id: 'p1',
        name: 'Milk',
        description: '',
        userId: 'user',
      ),
    );

    expect(field, findsNothing);
  });
}
