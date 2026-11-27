import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/list_query.dart';
import 'package:foodsavr/controllers/list_query_state.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/utils/view_mode_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reopening a list restores its selections independently', () async {
    SharedPreferences.setMockInitialValues({});
    final firstVisit = ListQueryState('collection.user.fridge');
    await firstVisit.restore();
    firstVisit.update(() {
      firstVisit.category = 'Dairy';
      firstVisit.status = ProductStatus.expiringSoon;
      firstVisit.sort = ListSort.expiry;
      firstVisit.viewMode = ProductViewMode.compact;
    });
    firstVisit.searchFor('milk');
    firstVisit.dispose();

    final nextVisit = ListQueryState('collection.user.fridge');
    final otherCollection = ListQueryState('collection.user.pantry');
    await Future.wait([nextVisit.restore(), otherCollection.restore()]);
    addTearDown(nextVisit.dispose);
    addTearDown(otherCollection.dispose);
    expect(nextVisit.query.category, 'dairy');
    expect(nextVisit.query.status, ProductStatus.expiringSoon);
    expect(nextVisit.query.sort, ListSort.expiry);
    expect(nextVisit.viewMode, ProductViewMode.compact);
    expect(nextVisit.query.search, isEmpty);
    expect(otherCollection.query.category, isNull);
    expect(otherCollection.query.status, isNull);
    expect(otherCollection.query.sort, ListSort.original);
    expect(otherCollection.viewMode, ProductViewMode.normal);
  });

  test(
    'saved legacy category filter is normalized and matches migrated products',
    () async {
      SharedPreferences.setMockInitialValues({
        'listQuery.collection.user.fridge': jsonEncode({'category': 'Dairy'}),
      });

      final state = ListQueryState('collection.user.fridge');
      await state.restore();
      addTearDown(state.dispose);

      expect(state.category, 'dairy');
      expect(state.query.category, 'dairy');

      final migratedProduct = Product.fromJson({
        'id': 'milk-1',
        'name': 'Whole Milk',
        'description': '',
        'userId': 'user-1',
        'category': 'Dairy',
      });

      final matched = state.query.apply(
        [migratedProduct],
        now: DateTime(2026, 11, 27),
        expiringSoonDays: 3,
      );

      expect(matched.map((p) => p.id), ['milk-1']);
    },
  );
}
