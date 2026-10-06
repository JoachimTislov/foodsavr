import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_product_repository.dart';
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
  int getProductsCalls = 0;

  _GatedProductRepository(this._products, this._gate);

  @override
  Future<Product> add(Product entity) async => entity;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<Product?> get(String id) async => null;

  @override
  Future<List<Product>> getAll() async => _products;

  @override
  Future<List<Product>> getGlobalProducts() async => _products;

  @override
  Future<List<Product>> getPersonalProducts(String userId) async => _products;

  @override
  Future<List<Product>> getProducts(String userId) async {
    getProductsCalls++;
    await _gate.future;
    return _products;
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
  Future<void> delete(String id) async {}

  @override
  Future<Product?> get(String id) async {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<List<Product>> getAll() async => _products;

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

  test(
    'in-flight fetch does not write stale data after invalidation',
    () async {
      final gate = Completer<void>();
      final repository = _GatedProductRepository([_product('p1')], gate);
      final service = makeService(repository);

      final first = service.getProducts('user-1');
      await service.deleteProduct('p1');
      gate.complete();
      await first;

      await service.getProducts('user-1');
      expect(repository.getProductsCalls, 2);
    },
  );
}
