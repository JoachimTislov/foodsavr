import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_product_repository.dart';
import 'package:foodsavr/interfaces/i_validator.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

class _MockIValidatorProduct extends Mock implements IValidator<Product> {}

class _FixedProductRepository implements IProductRepository {
  final List<Product> products;

  _FixedProductRepository(this.products);

  @override
  Future<List<Product>> getProducts(String userId) async => products;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

void main() {
  ProductService makeService(List<Product> products) => ProductService(
    _FixedProductRepository(products),
    _MockIValidatorProduct(),
    _MockShelfLifeService(),
    Logger(level: Level.off),
  );

  test('sorts each expiry list by the entries that qualify for it', () async {
    final expired = _expiringIn('expired', -2);
    final soon = _expiringIn('soon', 0);
    final mixed = _expiringIn('mixed', -3).copyWith(
      expiries: [
        ..._expiringIn('later', 7).expiries,
        ..._expiringIn('past', -3).expiries,
        ..._expiringIn('tomorrow', 1).expiries,
      ],
    );
    final service = makeService([
      mixed,
      expired,
      soon,
      _expiringIn('later', 7),
    ]);

    expect(await service.getExpired('user-1'), [mixed, expired]);
    expect(await service.getExpiringSoon('user-1'), [soon, mixed]);
  });

  group('getExpired', () {
    test('returns expired products oldest first', () async {
      final service = makeService([
        _expiringIn('minus1', -1),
        _expiringIn('in3', 3),
        _expiringIn('minus10', -10),
        _expiringIn('today', 0),
      ]);

      final result = await service.getExpired('user-1');

      expect(result.map((p) => p.id), ['minus10', 'minus1']);
    });

    test('excludes products without an expiry', () async {
      final service = makeService([
        Product(id: 'plain', name: 'Plain', description: '', userId: 'user-1'),
      ]);

      expect(await service.getExpired('user-1'), isEmpty);
    });
  });
}
