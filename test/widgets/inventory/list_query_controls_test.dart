import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/list_query_state.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/widgets/inventory/list_query_controls.dart';

import '../../support/localized_app.dart';

void main() {
  setUpAll(setUpLocalizedApp);

  for (final language in ['en', 'nb']) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        'badges sit above the search field at $width px in $language',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          // The test font (Ahem) is far wider than the real one.
          tester.platformDispatcher.textScaleFactorTestValue = 0.6;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final state = ListQueryState('test');
          addTearDown(state.dispose);

          await pumpLocalized(
            tester,
            Scaffold(
              body: ListQueryControls(
                state: state,
                products: const [
                  Product(
                    id: 'milk',
                    name: 'Milk',
                    description: '',
                    userId: 'user',
                    category: 'dairy',
                  ),
                ],
                collections: const [
                  Collection(
                    id: 'fridge',
                    name: 'Fridge',
                    productIds: [],
                    userId: 'user',
                  ),
                ],
              ),
            ),
            language: language,
          );

          expect(tester.takeException(), isNull);
          final search = tester.getRect(find.byType(TextFormField));
          final badges = [
            ...find.byType(FilterChip).evaluate(),
            ...find.byType(Chip).evaluate(),
          ].map((e) => tester.getRect(find.byWidget(e.widget))).toList();
          // Every status, plus category, collection and sort.
          expect(badges, hasLength(ProductStatus.values.length + 3));
          for (final badge in badges) {
            expect(badge.top, lessThan(search.top));
            expect(badge.bottom, lessThanOrEqualTo(search.top - 12));
            expect(badge.left, greaterThanOrEqualTo(0));
            expect(badge.right, lessThanOrEqualTo(width));
          }
          for (var i = 0; i < badges.length; i++) {
            for (var j = i + 1; j < badges.length; j++) {
              expect(badges[i].overlaps(badges[j]), isFalse);
            }
          }
        },
      );
    }
  }
}
