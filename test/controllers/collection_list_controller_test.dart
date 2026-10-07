import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/collection_list_controller.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/utils/collection_types.dart';

Collection _collection(CollectionType type) => Collection(
      id: 'id-${type.name}',
      name: type.name,
      productIds: const [],
      userId: 'user_1',
      type: type,
    );

void main() {
  group('CollectionListController', () {
    test('initial state is empty', () {
      final controller = CollectionListController();
      expect(controller.collections, isEmpty);
    });

    test('loadCollections filters by the given type', () {
      final controller = CollectionListController();
      controller.loadCollections(
        [
          _collection(CollectionType.inventory),
          _collection(CollectionType.shoppingList),
        ],
        CollectionType.shoppingList,
      );
      expect(controller.collections, hasLength(1));
      expect(controller.collections.single.type, CollectionType.shoppingList);
    });

    test('loadCollections defaults to inventories without a filter', () {
      final controller = CollectionListController();
      controller.loadCollections(
        [
          _collection(CollectionType.inventory),
          _collection(CollectionType.shoppingList),
        ],
        null,
      );
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
      controller.loadCollections(
        [_collection(CollectionType.inventory)],
        CollectionType.inventory,
      );
      var notified = false;
      controller.addListener(() => notified = true);
      controller.clear();
      expect(notified, true);
      expect(controller.collections, isEmpty);
    });
  });
}
