import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart';
import 'package:foodsavr/interfaces/i_validator.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ICollectionRepository {}

class _MockValidator extends Mock implements IValidator<Collection> {}

void main() {
  late _MockRepository repository;
  late CollectionService service;
  const collection = Collection(
    id: 'c1',
    name: 'Fridge',
    productIds: ['a', 'ghost', 'b', 'ghost-2'],
    userId: 'u1',
  );
  Product product(String id) =>
      Product(id: id, name: id, description: '', userId: 'u1');

  setUp(() {
    repository = _MockRepository();
    service = CollectionService(
      repository,
      _MockValidator(),
      Logger(level: Level.off),
    );
    when(
      () => repository.getMemberProducts('u1'),
    ).thenAnswer((_) async => [product('a'), product('b'), product('x')]);
    when(
      () => repository.removeProducts(any(), any()),
    ).thenAnswer((_) async {});
  });

  test('loadContents drops dangling IDs with one exact removal', () async {
    final (cleaned, products) = await service.loadContents(collection);

    expect(products.map((p) => p.id), ['a', 'b']);
    expect(cleaned.productIds, ['a', 'b']);
    final removed =
        verify(
              () => repository.removeProducts('c1', captureAny()),
            ).captured.single
            as Iterable<String>;
    expect(removed.toSet(), {'ghost', 'ghost-2'});
    verifyNever(() => repository.addProducts(any(), any()));
  });

  test('resolveCounts excludes dangling IDs and repairs them', () async {
    final counts = await service.resolveCounts('u1', [collection]);

    expect(counts, {'c1': 2});
    final removed =
        verify(
              () => repository.removeProducts('c1', captureAny()),
            ).captured.single
            as Iterable<String>;
    expect(removed.toSet(), {'ghost', 'ghost-2'});
  });

  test('a clean collection triggers no repair write', () async {
    const clean = Collection(
      id: 'c2',
      name: 'Clean',
      productIds: ['a'],
      userId: 'u1',
    );
    await service.loadContents(clean);
    await service.resolveCounts('u1', [clean]);

    verifyNever(() => repository.removeProducts(any(), any()));
  });

  test('a failed repair never fails the read', () async {
    when(
      () => repository.removeProducts(any(), any()),
    ).thenThrow(Exception('offline'));

    final (_, products) = await service.loadContents(collection);
    final counts = await service.resolveCounts('u1', [collection]);

    expect(products.map((p) => p.id), ['a', 'b']);
    expect(counts, {'c1': 2});
  });
}
