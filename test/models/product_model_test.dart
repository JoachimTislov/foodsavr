import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';

Product _expiringIn(int days) {
  final now = DateTime.now();
  return Product(
    id: '1',
    name: 'Milk',
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
  group('Product serialization', () {
    test('preserves registryType and mappedFromProductId', () {
      final product = Product(
        id: '1',
        name: 'Milk',
        description: 'Dairy milk',
        userId: 'user-1',
        registryType: 'current',
        mappedFromProductId: '42',
      );

      final json = product.toJson();
      final parsed = Product.fromJson(json);

      expect(parsed.registryType, 'current');
      expect(parsed.mappedFromProductId, '42');
    });
  });

  group('Product expiring-soon window', () {
    test('defaults to 6 days', () {
      expect(_expiringIn(6).isExpiringSoon, isTrue);
      expect(_expiringIn(7).isExpiringSoon, isFalse);
      expect(_expiringIn(6).status, ProductStatus.expiringSoon);
      expect(_expiringIn(7).status, ProductStatus.fresh);
    });

    test('isExpiringSoonWithin honors a custom window', () {
      expect(_expiringIn(10).isExpiringSoonWithin(10), isTrue);
      expect(_expiringIn(11).isExpiringSoonWithin(10), isFalse);
      expect(_expiringIn(4).isExpiringSoonWithin(3), isFalse);
    });

    test('today is never inside the window; it is its own state', () {
      expect(_expiringIn(0).isExpiringSoonWithin(3), isFalse);
      expect(_expiringIn(0).statusWithin(3), ProductStatus.expiringSoon);
    });

    test('statusWithin follows the window; expired stays expired', () {
      expect(_expiringIn(5).statusWithin(3), ProductStatus.fresh);
      expect(_expiringIn(5).statusWithin(5), ProductStatus.expiringSoon);
      expect(_expiringIn(-1).statusWithin(30), ProductStatus.expired);
    });
  });
}
