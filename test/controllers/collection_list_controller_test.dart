import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/collection_list_controller.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/utils/collection_types.dart';

const _inventory = Collection(
  id: 'inventory',
  name: 'inventory',
  productIds: [],
  userId: 'user_1',
  type: CollectionType.inventory,
);

const _shoppingList = Collection(
  id: 'shopping-list',
  name: 'shopping-list',
  productIds: [],
  userId: 'user_1',
  type: CollectionType.shoppingList,
);

void main() {
  group('CollectionListController', () {
    test('initial state is empty', () {
      final controller = CollectionListController();
      expect(controller.collections, isEmpty);
    });

    test('loadCollections filters by the given type', () {
      final controller = CollectionListController();
      controller.loadCollections([
        _inventory,
        _shoppingList,
      ], CollectionType.shoppingList);
      expect(controller.collections, hasLength(1));
      expect(controller.collections.single.type, CollectionType.shoppingList);
    });

    test('loadCollections defaults to inventories without a filter', () {
      final controller = CollectionListController();
      controller.loadCollections([_inventory, _shoppingList], null);
      expect(controller.collections, hasLength(1));
      expect(controller.collections.single.type, CollectionType.inventory);
    });

    test('loadCollections notifies listeners', () {
      final controller = CollectionListController();
      var notified = false;
      controller.addListener(() => notified = true);
      controller.loadCollections(const [], null);
      expect(notified, true);
    });

    test('clear empties the list and notifies', () {
      final controller = CollectionListController();
      controller.loadCollections([_inventory], CollectionType.inventory);
      var notified = false;
      controller.addListener(() => notified = true);
      controller.clear();
      expect(notified, true);
      expect(controller.collections, isEmpty);
    });
  });
}
