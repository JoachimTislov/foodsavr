import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/validation/validators/collection_model_validator.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements ICollectionRepository {}

/// Accounts created before provisioning was dropped still hold these IDs.
const _inventory = Collection(
  id: 'initial-inventory-user',
  name: 'Inventory',
  userId: 'user',
  type: CollectionType.inventory,
  productIds: [],
);
const _shoppingList = Collection(
  id: 'initial-shopping-list-user',
  name: 'Shopping List',
  userId: 'user',
  type: CollectionType.shoppingList,
  productIds: [],
);

void main() {
  late _Repository repository;
  late Map<String, Collection> stored;
  late CollectionService service;

  setUp(() {
    repository = _Repository();
    stored = {
      for (final collection in [_inventory, _shoppingList])
        collection.id: collection,
    };
    when(
      () => repository.getCollections('user'),
    ).thenAnswer((_) async => stored.values.toList());
    when(() => repository.delete(any())).thenAnswer((call) async {
      stored.remove(call.positionalArguments.single);
    });
    service = CollectionService(
      repository,
      CollectionModelValidator(),
      Logger(level: Level.off),
    );
  });

  test('deletes the last initial inventory and shopping list', () async {
    await service.deleteCollectionOnly(_inventory.id);
    expect(await service.getCollectionsForUser('user'), [_shoppingList]);

    await service.deleteCollectionOnly(_shoppingList.id);

    expect(await service.getCollectionsForUser('user'), isEmpty);
    expect(await service.resolveCounts('user', const []), isEmpty);
    // Nothing is written back in their place.
    verifyNever(() => repository.addCollectionsInBatch(any()));
  });

  test('reads of an account without collections write nothing', () async {
    stored.clear();

    expect(await service.getCollectionsForUser('user'), isEmpty);
    expect(
      await service.getCollectionsForUser(
        'user',
        type: CollectionType.shoppingList,
      ),
      isEmpty,
    );
    expect(await service.getInventoryNamesForProducts('user', {'milk'}), {});
    expect(await service.getInventoriesByProductId('user', 'milk'), isEmpty);

    verify(() => repository.getCollections('user'));
    verifyNoMoreInteractions(repository);
  });
}
