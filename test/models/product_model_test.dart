import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';

void main() {
  group('Product serialization', () {
    test('preserves registryType and mappedFromProductId', () {
      final product = Product(
        id: 1,
        name: 'Milk',
        description: 'Dairy milk',
        userId: 'user-1',
        registryType: 'current',
        mappedFromProductId: 42,
      );

      final json = product.toJson();
      final parsed = Product.fromJson(json);

      expect(parsed.registryType, 'current');
      expect(parsed.mappedFromProductId, 42);
    });

    test('infers global registryType from legacy isGlobal field', () {
      final parsed = Product.fromJson({
        'id': 2,
        'name': 'Rice',
        'description': 'White rice',
        'userId': 'global',
        'isGlobal': true,
      });

      expect(parsed.registryType, 'global');
    });

    test('defaults to current registryType for legacy non-global products', () {
      final parsed = Product.fromJson({
        'id': 3,
        'name': 'Eggs',
        'description': 'Fresh eggs',
        'userId': 'user-1',
        'isGlobal': false,
      });

      expect(parsed.registryType, 'current');
      expect(parsed.mappedFromProductId, isNull);
    });
  });
}
