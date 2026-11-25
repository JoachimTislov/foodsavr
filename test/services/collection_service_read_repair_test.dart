import 'dart:async';

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
    when(() => repository.getMemberProducts('u1')).thenAnswer(
      (_) async => (
        products: [product('a'), product('b'), product('x')],
        authoritative: true,
      ),
    );
    when(
      () => repository.isProductMissingOrUnreadable(any()),
    ).thenAnswer((_) async => true);
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

  test(
    'incomplete cache supplies counts and contents without repair',
    () async {
      when(() => repository.getMemberProducts('u1')).thenAnswer(
        (_) async => (products: [product('a')], authoritative: false),
      );

      final (loaded, visible) = await service.loadContents(collection);
      expect(loaded.productIds, ['a']);
      expect(visible.map((product) => product.id), ['a']);
      expect(await service.resolveCounts('u1', [collection]), {'c1': 1});
      verifyNever(() => repository.isProductMissingOrUnreadable(any()));
      verifyNever(() => repository.removeProducts(any(), any()));
    },
  );

  test(
    'repair skips an ID that a direct server read can still resolve',
    () async {
      when(
        () => repository.isProductMissingOrUnreadable('ghost'),
      ).thenAnswer((_) async => false);

      final (loaded, _) = await service.loadContents(collection);

      expect(loaded.productIds, ['a', 'b']);
      final removed =
          verify(
                () => repository.removeProducts('c1', captureAny()),
              ).captured.single
              as Iterable<String>;
      expect(removed, ['ghost-2']);
    },
  );

  test('a failed server confirmation never prunes or fails the read', () async {
    when(
      () => repository.isProductMissingOrUnreadable(any()),
    ).thenThrow(Exception('unavailable'));

    final (loaded, visible) = await service.loadContents(collection);

    expect(loaded.productIds, ['a', 'b']);
    expect(visible.map((product) => product.id), ['a', 'b']);
    expect(await service.resolveCounts('u1', [collection]), {'c1': 2});
    verifyNever(() => repository.removeProducts(any(), any()));
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

  test('a queued repair does not delay a read', () async {
    final acknowledgement = Completer<void>();
    addTearDown(acknowledgement.complete);
    when(
      () => repository.removeProducts(any(), any()),
    ).thenAnswer((_) => acknowledgement.future);

    final (_, visible) = await service.loadContents(collection);
    expect(visible.map((product) => product.id), ['a', 'b']);
    expect(await service.resolveCounts('u1', [collection]), {'c1': 2});
    expect(acknowledgement.isCompleted, isFalse);
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
