import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/widgets/dashboard/expiring_item_card.dart';
import 'package:foodsavr/widgets/dashboard/expiring_soon_section.dart';

import '../../support/localized_app.dart';

void main() {
  setUpAll(setUpLocalizedApp);

  testWidgets('an empty section renders nothing', (tester) async {
    await pumpLocalized(
      tester,
      const Scaffold(body: ExpiringSoonSection(products: [])),
    );

    expect(find.text('Expiring Soon'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(ExpiringItemCard), findsNothing);
  });

  testWidgets('a filled section lists its products without actions', (
    tester,
  ) async {
    final now = DateTime.now();
    await pumpLocalized(
      tester,
      Scaffold(
        body: ExpiringSoonSection(
          products: [
            Product(
              id: 'milk',
              name: 'Milk',
              description: '',
              userId: 'user',
              expiries: [
                ExpiryEntry(
                  quantity: 1,
                  expirationDate: DateTime(now.year, now.month, now.day + 2),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('Expiring Soon'), findsOneWidget);
    expect(find.byType(ExpiringItemCard), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.textContaining('View'), findsNothing);
  });
}
