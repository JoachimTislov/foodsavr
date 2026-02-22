import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:mocktail/mocktail.dart';
import 'package:logger/logger.dart';

class MockICollectionRepository extends Mock implements ICollectionRepository {}

void main() {
  late CollectionService collectionService;
  late MockICollectionRepository mockRepository;

  setUp(() {
    mockRepository = MockICollectionRepository();
    collectionService = CollectionService(mockRepository, Logger());
  });

  test('getInventoriesByProductId returns correct inventories', () async {
    final userId = 'user123';
    final productId = 1;
    final collections = [
      Collection(
        id: 'c1',
        name: 'Pantry',
        productIds: [1, 2],
        userId: userId,
        type: CollectionType.inventory,
      ),
      Collection(
        id: 'c2',
        name: 'Fridge',
        productIds: [1, 3],
        userId: userId,
        type: CollectionType.inventory,
      ),
      Collection(
        id: 'c3',
        name: 'Shopping',
        productIds: [1],
        userId: userId,
        type: CollectionType.shoppingList,
      ),
    ];

    when(
      () => mockRepository.getCollections(userId),
    ).thenAnswer((_) async => collections);

    final results = await collectionService.getInventoriesByProductId(
      userId,
      productId,
    );

    expect(results.length, 2);
    expect(results.any((c) => c.name == 'Pantry'), isTrue);
    expect(results.any((c) => c.name == 'Fridge'), isTrue);
    expect(results.any((c) => c.name == 'Shopping'), isFalse);
  });
}
