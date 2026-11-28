import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/validation/validators/collection_model_validator.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements ICollectionRepository {}

Collection _named(String name, {CollectionType? type}) => Collection(
  id: name,
  name: name,
  userId: 'user',
  type: type ?? CollectionType.inventory,
  productIds: const [],
);

void main() {
  group('uniqueName', () {
    test('keeps a free name', () {
      expect(CollectionService.uniqueName('Inventory', const []), 'Inventory');
      expect(
        CollectionService.uniqueName('Inventory', const ['Pantry']),
        'Inventory',
      );
    });

    test('numbers a taken name, ignoring case and spacing', () {
      expect(
        CollectionService.uniqueName('Inventory', const [' inventory ']),
        'Inventory 2',
      );
      expect(
        CollectionService.uniqueName('Inventory', const [
          'Inventory',
          'Inventory 2',
        ]),
        'Inventory 3',
      );
    });
  });

  group('with a repository', () {
    late _Repository repository;
    late CollectionService service;
    late List<Collection> stored;

    setUpAll(() => registerFallbackValue(_named('x')));

    setUp(() {
      repository = _Repository();
      stored = [];
      when(
        () => repository.getCollections('user'),
      ).thenAnswer((_) async => List.of(stored));
      when(() => repository.add(any())).thenAnswer((call) async {
        final added = (call.positionalArguments.single as Collection).copyWith(
          id: 'id${stored.length}',
        );
        stored.add(added);
        return added;
      });
      when(
        () =>
            repository.update(any(), metadataOnly: any(named: 'metadataOnly')),
      ).thenAnswer((_) async {});
      service = CollectionService(
        repository,
        CollectionModelValidator(),
        Logger(level: Level.off),
      );
    });

    test('createWithDefaultName avoids names of the same type', () async {
      stored.add(_named('Shopping list', type: CollectionType.shoppingList));

      final inventory = await service.createWithDefaultName(
        'user',
        CollectionType.inventory,
        baseName: 'Inventory',
      );
      final second = await service.createWithDefaultName(
        'user',
        CollectionType.inventory,
        baseName: 'Inventory',
      );
      final list = await service.createWithDefaultName(
        'user',
        CollectionType.shoppingList,
        baseName: 'Shopping list',
      );

      expect(inventory.name, 'Inventory');
      expect(second.name, 'Inventory 2');
      expect(list.name, 'Shopping list 2');
    });

    test('rename saves the trimmed name as metadata', () async {
      final renamed = await service.rename(_named('Old'), '  Cellar ');

      expect(renamed.name, 'Cellar');
      verify(() => repository.update(renamed, metadataOnly: true)).called(1);
    });

    test('rename keeps a blank or unchanged name without saving', () async {
      final collection = _named('Old');

      expect(await service.rename(collection, '   '), collection);
      expect(await service.rename(collection, 'Old'), collection);
      verifyNever(
        () =>
            repository.update(any(), metadataOnly: any(named: 'metadataOnly')),
      );
    });
  });
}
