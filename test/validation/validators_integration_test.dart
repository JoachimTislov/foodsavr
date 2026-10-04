import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:foodsavr/validation/validators/collection_model_validator.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validation_result.dart';

void main() {
  final validator = ProductModelValidator();

  group('ProductModelValidator', () {
    test('accepts a valid product', () {
      final product = Product(
        id: 'p1',
        name: 'Milk',
        description: '',
        userId: 'u1',
        expiries: [
          ExpiryEntry(
            quantity: 1,
            expirationDate: DateTime.now().add(const Duration(days: 3)),
          ),
        ],
      );
      final result = validator.validate(product);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('rejects empty name', () {
      final product = Product(
        id: 'p2',
        name: '   ',
        description: '',
        userId: 'u1',
      );
      final result = validator.validate(product);
      expect(result.isValid, isFalse);
      expect(result.errors.single.field, 'name');
    });

    test('rejects negative non-expiring quantity', () {
      final product = Product(
        id: 'p3',
        name: 'Milk',
        description: '',
        userId: 'u1',
        nonExpiringQuantity: -1,
      );
      final result = validator.validate(product);
      expect(result.isValid, isFalse);
      expect(result.errors.single.field, 'nonExpiringQuantity');
    });

    test('rejects non-positive expiry quantities with index', () {
      final product = Product(
        id: 'p4',
        name: 'Milk',
        description: '',
        userId: 'u1',
        expiries: [
          ExpiryEntry(
            quantity: 0,
            expirationDate: DateTime.now().add(const Duration(days: 1)),
          ),
          ExpiryEntry(
            quantity: -2,
            expirationDate: DateTime.now().add(const Duration(days: 2)),
          ),
        ],
      );
      final result = validator.validate(product);
      expect(result.isValid, isFalse);
      expect(result.errors.length, 2);
      expect(result.errors[0].field, 'expiries[0].quantity');
      expect(result.errors[1].field, 'expiries[1].quantity');
    });

    test('ValidationResult equality and toString', () {
      const a = ValidationResult([]);
      const b = ValidationResult([]);
      expect(a, b);
      expect(a.toString(), contains('ValidationResult'));
    });
  });

  group('CollectionModelValidator', () {
    final collectionValidator = CollectionModelValidator();

    test('accepts a valid collection', () {
      const collection = Collection(
        id: 'c1',
        name: 'Fridge',
        productIds: [],
        userId: 'u1',
      );
      final result = collectionValidator.validate(collection);
      expect(result.isValid, isTrue);
    });

    test('rejects empty collection name', () {
      const collection = Collection(
        id: 'c2',
        name: ' ',
        productIds: [],
        userId: 'u1',
      );
      final result = collectionValidator.validate(collection);
      expect(result.isValid, isFalse);
      expect(result.errors.single.field, 'name');
    });
  });

  group('ShelfLifeService', () {
    final shelfLife = ShelfLifeService();
    final added = DateTime(2026, 1, 1);

    Product tagged(List<String> tags) => Product(
      id: 't',
      name: 'Item',
      description: '',
      userId: 'u1',
      tags: tags,
    );

    test('estimates from a known category tag', () {
      final result = shelfLife.estimateExpiration(
        tagged(['en:milks']),
        addedDate: added,
      );
      expect(result, isNotNull);
      expect(result!.difference(added).inDays, 10);
    });

    test('normalizes tag casing and whitespace', () {
      final result = shelfLife.estimateExpiration(
        tagged(['  EN:FRESH-MEATS ']),
        addedDate: added,
      );
      expect(result, isNotNull);
      expect(result!.difference(added).inDays, 4);
    });

    test('uses first matching tag', () {
      final result = shelfLife.estimateExpiration(
        tagged(['unknown-tag', 'en:breads']),
        addedDate: added,
      );
      expect(result!.difference(added).inDays, 5);
    });

    test('falls back to category string matching', () {
      final dairy = Product(
        id: 't',
        name: 'Item',
        description: '',
        userId: 'u1',
        category: 'dairy drink',
      );
      final result = shelfLife.estimateExpiration(dairy, addedDate: added);
      expect(result, isNotNull);
      expect(result!.difference(added).inDays, 10);
    });

    test('returns null when nothing matches', () {
      final unknown = Product(
        id: 't',
        name: 'Item',
        description: '',
        userId: 'u1',
        category: 'mystery',
      );
      expect(shelfLife.estimateExpiration(unknown, addedDate: added), isNull);
      expect(
        shelfLife.estimateExpiration(tagged([]), addedDate: added),
        isNull,
      );
    });
  });
}
