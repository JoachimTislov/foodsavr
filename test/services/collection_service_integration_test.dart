import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart';
import 'package:foodsavr/interfaces/i_validator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/validation/validation_error.dart';
import 'package:foodsavr/validation/validation_result.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class _MockCollectionRepository extends Mock
    implements ICollectionRepository {}

class _StubCollectionValidator implements IValidator<Collection> {
  @override
  ValidationResult validate(Collection instance) {
    if (instance.name.trim().isEmpty) {
      return const ValidationResult([
        ValidationError(
          field: 'name',
          message: 'Collection name cannot be empty',
        ),
      ]);
    }
    return const ValidationResult([]);
  }
}

void main() {
  late _MockCollectionRepository repository;
  late CollectionService service;

  const inventory = Collection(
    id: 'inv-1',
    name: 'Home Fridge',
    productIds: ['p-1', 'p-2'],
    userId: 'user-123',
    type: CollectionType.inventory,
  );
  const shoppingList = Collection(
    id: 'shop-1',
    name: 'Weekly List',
    productIds: ['p-1'],
    userId: 'user-123',
    type: CollectionType.shoppingList,
  );

  setUp(() {
    repository = _MockCollectionRepository();
    service = CollectionService(
      repository,
      _StubCollectionValidator(),
      Logger(filter: ProductionFilter()),
    );
  });

  group('getCollectionsForUser', () {
    test('returns empty list when userId is null', () async {
      expect(await service.getCollectionsForUser(null), isEmpty);
      verifyNever(() => repository.getCollections(any()));
    });

    test('returns collections filtered by type', () async {
      when(() => repository.getCollections('user-123'))
          .thenAnswer((_) async => [inventory, shoppingList]);

      final all = await service.getCollectionsForUser('user-123');
      expect(all.length, 2);

      final listsOnly = await service.getCollectionsForUser(
        'user-123',
        type: CollectionType.shoppingList,
      );
      expect(listsOnly, [shoppingList]);
    });

    test('rethrows repository errors', () async {
      when(() => repository.getCollections('user-123'))
          .thenThrow(StateError('firestore down'));
      await expectLater(
        service.getCollectionsForUser('user-123'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('inventory lookups', () {
    setUp(() {
      when(() => repository.getCollections('user-123'))
          .thenAnswer((_) async => [inventory, shoppingList]);
    });

    test('getInventoriesByProductId finds containing inventories', () async {
      final result = await service.getInventoriesByProductId(
        'user-123',
        'p-1',
      );
      expect(result, [inventory]);
    });

    test('getInventoriesByProductId excludes non-inventory collections',
        () async {
      final result = await service.getInventoriesByProductId(
        'user-123',
        'p-2',
      );
      expect(result, isEmpty);
    });

    test('getInventoryNamesForProducts maps product id to inventory names',
        () async {
      final map = await service.getInventoryNamesForProducts(
        'user-123',
        const {'p-1'},
      );
      expect(map['p-1'], ['Home Fridge']);
    });
  });

  group('getCollection', () {
    test('delegates to repository and returns result', () async {
      when(() => repository.get('inv-1')).thenAnswer((_) async => inventory);
      expect(await service.getCollection('inv-1'), inventory);
    });

    test('returns null when repository returns null', () async {
      when(() => repository.get('missing')).thenAnswer((_) async => null);
      expect(await service.getCollection('missing'), isNull);
    });
  });

  group('addCollection', () {
    test('throws FormatException for invalid collection', () async {
      const invalid = Collection(
        id: 'bad',
        name: '  ',
        productIds: [],
        userId: 'user-123',
      );
      await expectLater(
        service.addCollection(invalid),
        throwsA(isA<FormatException>()),
      );
      verifyNever(() => repository.add(any()));
    });

    test('persists valid collection through repository', () async {
      when(() => repository.add(any)).thenAnswer((_) async => inventory);
      final result = await service.addCollection(inventory);
      expect(result, inventory);
      verify(() => repository.add(inventory)).called(1);
    });
  });

  group('updateCollection', () {
    test('throws FormatException for invalid collection', () async {
      const invalid = Collection(
        id: 'bad',
        name: '',
        productIds: [],
        userId: 'user-123',
      );
      await expectLater(
        service.updateCollection(invalid),
        throwsA(isA<FormatException>()),
      );
      verifyNever(() => repository.update(any()));
    });

    test('delegates valid updates to repository', () async {
      when(() => repository.update(any)).thenAnswer((_) async {});
      await service.updateCollection(inventory);
      verify(() => repository.update(inventory)).called(1);
    });
  });

  group('deleteCollection', () {
    test('deletes through repository', () async {
      when(() => repository.delete('inv-1')).thenAnswer((_) async {});
      await service.deleteCollection('inv-1');
      verify(() => repository.delete('inv-1')).called(1);
    });

    test('rethrows repository errors', () async {
      when(() => repository.delete('inv-1'))
          .thenThrow(StateError('delete failed'));
      await expectLater(
        service.deleteCollection('inv-1'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
