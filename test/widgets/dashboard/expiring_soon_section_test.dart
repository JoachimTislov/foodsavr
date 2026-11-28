import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/widgets/dashboard/expiring_item_card.dart';
import 'package:foodsavr/widgets/dashboard/expiring_soon_section.dart';
import 'package:foodsavr/widgets/dashboard/register_expiry_card.dart';

import '../../support/localized_app.dart';

void main() {
  setUpAll(setUpLocalizedApp);

  for (final (language, empty, register) in [
    ('en', 'No products expiring soon.', 'Register Expiry'),
    ('nb', 'Ingen produkter utløper snart.', 'Registrer utløpsdato'),
  ]) {
    testWidgets('empty section offers to register an expiry in $language', (
      tester,
    ) async {
      var registered = 0;
      await pumpLocalized(
        tester,
        Scaffold(
          body: ExpiringSoonSection(
            products: const [],
            onRegisterExpiry: () => registered++,
          ),
        ),
        language: language,
      );

      expect(find.text(empty), findsOneWidget);
      await tester.tap(find.text(register));

      expect(registered, 1);
      expect(find.byType(TextButton), findsNothing);
    });
  }

  testWidgets('a filled section has no View all button and no fallback', (
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
          onRegisterExpiry: () {},
        ),
      ),
    );

    expect(find.byType(ExpiringItemCard), findsOneWidget);
    expect(find.byType(RegisterExpiryCard), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.textContaining('View'), findsNothing);
  });
}
