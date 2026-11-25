import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_product_repository.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:foodsavr/interfaces/i_validator.dart';
import 'package:foodsavr/validation/validation_result.dart';

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

class _MockIValidatorProduct extends Mock implements IValidator<Product> {}

class _FakeProduct extends Fake implements Product {}

class _GatedProductRepository implements IProductRepository {
  final List<Product> _products;
  final Completer<void> _gate;
  final deleteGate = Completer<void>();
  int getProductsCalls = 0;

  _GatedProductRepository(this._products, this._gate);

  @override
  Future<Product> add(Product entity) async => entity;

  @override
  Future<void> deleteCollection(Collection source, {String? destinationId}) =>
      delete(source.productIds.single);

  @override
  Future<void> delete(String id) async {
    await deleteGate.future;
    _products.removeWhere((product) => product.id == id);
  }

  @override
  Future<Product?> get(String id) async => null;

  @override
  Future<List<Product>> getGlobalProducts() async => _products;

  @override
  Future<List<Product>> getPersonalProducts(String userId) async => _products;

  @override
  Future<List<Product>> getProducts(String userId) async {
    getProductsCalls++;
    final snapshot = List<Product>.of(_products);
    if (getProductsCalls == 1) await _gate.future;
    return snapshot;
  }

  @override
  Future<void> update(Product entity) async {}
}

class _CountingProductRepository implements IProductRepository {
  final List<Product> _products;
  int getProductsCalls = 0;

  _CountingProductRepository(this._products);

  @override
  Future<Product> add(Product entity) async => entity;

  @override
  Future<void> deleteCollection(Collection source, {String? destinationId}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) async {}

  @override
  Future<Product?> get(String id) async {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<List<Product>> getGlobalProducts() async => _products;

  @override
  Future<List<Product>> getPersonalProducts(String userId) async => _products;

  @override
  Future<List<Product>> getProducts(String userId) async {
    getProductsCalls++;
    return _products;
  }

  @override
  Future<void> update(Product entity) async {}
}

Product _product(String id) =>
    Product(id: id, name: 'Product $id', description: '', userId: 'user-1');

void main() {
  late _MockIValidatorProduct mockProductValidator;
  late _MockShelfLifeService mockShelfLifeService;

  setUpAll(() {
    registerFallbackValue(_FakeProduct());
  });

  setUp(() {
    mockProductValidator = _MockIValidatorProduct();
    mockShelfLifeService = _MockShelfLifeService();
    when(
      () => mockProductValidator.validate(any()),
    ).thenReturn(const ValidationResult([]));
  });

  ProductService makeService(IProductRepository repository) => ProductService(
    repository,
    mockProductValidator,
    mockShelfLifeService,
    Logger(),
  );

  group('getExpiringSoon', () {
    final products = [
      _expiringIn('today', 0),
      _expiringIn('in3', 3),
      _expiringIn('in10', 10),
      _expiringIn('in20', 20),
    ];

    test('uses a 6 day window by default', () async {
      final service = makeService(_CountingProductRepository(products));

      final result = await service.getExpiringSoon('user-1');

      expect(result.map((p) => p.id), ['today', 'in3']);
    });

    test('honors a custom window', () async {
      final service = makeService(_CountingProductRepository(products));

      final result = await service.getExpiringSoon(
        'user-1',
        expiringSoonDays: 14,
      );

      expect(result.map((p) => p.id), ['today', 'in3', 'in10']);
    });
  });

  test('getProducts caches per user within TTL', () async {
    final repository = _CountingProductRepository([_product('p1')]);
    final service = makeService(repository);

    await service.getProducts('user-1');
    await service.getProducts('user-1');

    expect(repository.getProductsCalls, 1);
  });

  test('getProducts with forceRefresh bypasses the cache', () async {
    final repository = _CountingProductRepository([_product('p1')]);
    final service = makeService(repository);

    await service.getProducts('user-1');
    await service.getProducts('user-1', forceRefresh: true);

    expect(repository.getProductsCalls, 2);
  });

  test('mutation invalidates the cache', () async {
    final repository = _CountingProductRepository([_product('p1')]);
    final service = makeService(repository);

    await service.getProducts('user-1');
    await service.deleteProduct('p1');
    await service.getProducts('user-1');

    expect(repository.getProductsCalls, 2);
  });

  test('cache is scoped per user', () async {
    final repository = _CountingProductRepository([_product('p1')]);
    final service = makeService(repository);

    await service.getProducts('user-1');
    await service.getProducts('user-2');

    expect(repository.getProductsCalls, 2);
  });

  test('concurrent dashboard lists share one in-flight fetch', () async {
    final gate = Completer<void>();
    final repository = _GatedProductRepository([
      _expiringIn('soon', 1),
      _expiringIn('gone', -2),
    ], gate);
    final service = makeService(repository);

    final expired = service.getExpired('user-1');
    final upcoming = service.getExpiringSoon('user-1');
    gate.complete();

    expect((await expired).map((p) => p.id), ['gone']);
    expect((await upcoming).map((p) => p.id), ['soon']);
    expect(repository.getProductsCalls, 1);
  });

  for (final deleteCollection in [false, true]) {
    for (final fetchCompletesFirst in [true, false]) {
      test(
        '${deleteCollection ? 'collection' : 'product'} delete invalidates '
        'a read started during its write (fetch first: $fetchCompletesFirst)',
        () async {
          final gate = Completer<void>();
          final repository = _GatedProductRepository([_product('p1')], gate);
          final service = makeService(repository);

          final deletion = deleteCollection
              ? service.deleteCollection(
                  const Collection(
                    id: 'c1',
                    name: 'Inventory',
                    productIds: ['p1'],
                    userId: 'user-1',
                  ),
                )
              : service.deleteProduct('p1');
          final stale = service.getProducts('user-1');
          if (fetchCompletesFirst) {
            gate.complete();
            expect((await stale).map((p) => p.id), ['p1']);
          }
          repository.deleteGate.complete();
          await deletion;

          final fresh = service.getProducts('user-1');
          expect(repository.getProductsCalls, 2);
          expect(await fresh, isEmpty);
          if (!fetchCompletesFirst) {
            gate.complete();
            expect(await stale, isEmpty);
          }
          expect(await service.getProducts('user-1'), isEmpty);
        },
      );
    }
  }
}

Product _expiringIn(String id, int days) {
  final now = DateTime.now();
  return Product(
    id: id,
    name: 'Product $id',
    description: '',
    userId: 'user-1',
    expiries: [
      ExpiryEntry(
        quantity: 1,
        expirationDate: DateTime(now.year, now.month, now.day + days),
      ),
    ],
  );
}
