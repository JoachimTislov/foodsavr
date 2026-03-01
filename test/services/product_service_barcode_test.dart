import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_product_repository.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:logger/logger.dart';

class _FakeProductRepository implements IProductRepository {
  final List<Product> _products;
  Product? updatedProduct;
  Product? addedProduct;

  _FakeProductRepository(this._products);

  @override
  Future<Product> add(Product entity) async {
    _products.add(entity);
    addedProduct = entity;
    return entity;
  }

  @override
  Future<void> delete(int id) async {
    _products.removeWhere((product) => product.id == id);
  }

  @override
  Future<Product?> get(int id) async {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<List<Product>> getAll() async => _products;

  @override
  Future<List<Product>> getGlobalProducts() async =>
      _products.where((product) => product.isGlobal).toList();

  @override
  Future<List<Product>> getProducts(String userId) async =>
      _products.where((product) => product.userId == userId).toList();

  @override
  Future<void> update(Product entity) async {
    updatedProduct = entity;
    final index = _products.indexWhere((product) => product.id == entity.id);
    if (index >= 0) _products[index] = entity;
  }
}

void main() {
  group('ProductService barcode scan handling', () {
    test('increments non-expiring quantity for existing barcode', () async {
      final repository = _FakeProductRepository([
        Product(
          id: 1,
          name: 'Milk',
          description: 'Dairy',
          userId: 'user-1',
          nonExpiringQuantity: 2,
          barcode: '1234567890',
        ),
      ]);
      final service = ProductService(repository, Logger(level: Level.off));

      final result = await service.addOrIncrementByBarcode(
        userId: 'user-1',
        barcode: '1234567890',
      );

      expect(result.matchedExisting, isTrue);
      expect(repository.updatedProduct, isNotNull);
      expect(repository.updatedProduct?.nonExpiringQuantity, 3);
      expect(repository.addedProduct, isNull);
    });

    test('creates product for unknown barcode', () async {
      final repository = _FakeProductRepository([]);
      final service = ProductService(repository, Logger(level: Level.off));

      final result = await service.addOrIncrementByBarcode(
        userId: 'user-1',
        barcode: '999001',
      );

      expect(result.matchedExisting, isFalse);
      expect(result.product.barcode, '999001');
      expect(result.product.nonExpiringQuantity, 1);
      expect(repository.addedProduct, isNotNull);
      expect(repository.updatedProduct, isNull);
    });

    test('throws ArgumentError for empty or whitespace barcode', () async {
      final repository = _FakeProductRepository([]);
      final service = ProductService(repository, Logger(level: Level.off));

      await expectLater(
        service.addOrIncrementByBarcode(userId: 'user-1', barcode: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Barcode cannot be empty',
          ),
        ),
      );
    });
  });
}
