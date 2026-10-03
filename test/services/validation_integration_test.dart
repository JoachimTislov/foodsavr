import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart';
import 'package:foodsavr/interfaces/i_product_repository.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validators/collection_model_validator.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class _MockCollectionRepository extends Mock implements ICollectionRepository {}

class _MockProductRepository extends Mock implements IProductRepository {}

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

Product _validProduct() {
  return Product(
    id: 'p1',
    name: 'Milk',
    description: 'Fresh milk',
    userId: 'user-1',
  );
}

Product _invalidProduct() {
  return _validProduct().copyWith(
    name: '   ',
    nonExpiringQuantity: -1,
    expiries: [
      ExpiryEntry(quantity: 0, expirationDate: DateTime(2027, 1, 1)),
    ],
  );
}

Collection _validCollection() {
  return Collection(
    id: 'c1',
    name: 'Inventory',
    productIds: const [],
    userId: 'user-1',
  );
}

Collection _invalidCollection() {
  return _validCollection().copyWith(name: '   ');
}

void main() {
  late _MockCollectionRepository mockCollectionRepository;
  late _MockProductRepository mockProductRepository;
  late _MockShelfLifeService mockShelfLifeService;
  late CollectionService collectionService;
  late ProductService productService;

  setUpAll(() {
    registerFallbackValue(_validProduct());
    registerFallbackValue(_validCollection());
  });

  setUp(() {
    mockCollectionRepository = _MockCollectionRepository();
    mockProductRepository = _MockProductRepository();
    mockShelfLifeService = _MockShelfLifeService();
    collectionService = CollectionService(
      mockCollectionRepository,
      CollectionModelValidator(),
      Logger(level: Level.off),
    );
    productService = ProductService(
      mockProductRepository,
      ProductModelValidator(),
      mockShelfLifeService,
      Logger(level: Level.off),
    );
  });

  group('CollectionModelValidator', () {
    test('accepts a valid collection', () {
      final result = CollectionModelValidator().validate(_validCollection());
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('rejects empty and whitespace-only names', () {
      final validator = CollectionModelValidator();
      for (final name in ['', '   ']) {
        final collection = _validCollection().copyWith(name: name);
        final result = validator.validate(collection);
        expect(result.isValid, isFalse);
        expect(result.errors.single.field, 'name');
      }
    });
  });

  group('ProductModelValidator', () {
    test('accepts a valid product', () {
      final result = ProductModelValidator().validate(_validProduct());
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('rejects an empty name', () {
      final validator = ProductModelValidator();
      final result = validator.validate(_validProduct().copyWith(name: ''));
      expect(result.isValid, isFalse);
      expect(result.errors.single.field, 'name');
    });

    test('rejects a negative non-expiring quantity', () {
      final validator = ProductModelValidator();
      final result = validator.validate(
        _validProduct().copyWith(nonExpiringQuantity: -1),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.field, 'nonExpiringQuantity');
    });

    test('rejects non-positive expiry quantities', () {
      final validator = ProductModelValidator();
      final entry = ExpiryEntry(
        quantity: 0,
        expirationDate: DateTime(2027, 1, 1),
      );
      final result = validator.validate(
        _validProduct().copyWith(expiries: [entry]),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.field, 'expiries[0].quantity');
    });

    test('accumulates all violations', () {
      final validator = ProductModelValidator();
      final entry = ExpiryEntry(
        quantity: -2,
        expirationDate: DateTime(2027, 1, 1),
      );
      final result = validator.validate(
        _validProduct().copyWith(
          name: '',
          nonExpiringQuantity: -1,
          expiries: [entry],
        ),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.length, 3);
    });
  });

  group('CollectionService validation integration', () {
    test('addCollection persists a valid collection', () async {
      final collection = _validCollection();
      when(
        () => mockCollectionRepository.add(any()),
      ).thenAnswer((_) async => collection);

      final added = await collectionService.addCollection(collection);

      expect(added, collection);
      verify(() => mockCollectionRepository.add(any())).called(1);
    });

    test('addCollection rejects an invalid collection', () async {
      await expectLater(
        collectionService.addCollection(_invalidCollection()),
        throwsFormatException,
      );
      verifyNever(() => mockCollectionRepository.add(any()));
    });

    test('updateCollection persists a valid collection', () async {
      when(
        () => mockCollectionRepository.update(any()),
      ).thenAnswer((_) async {});

      await collectionService.updateCollection(_validCollection());

      verify(() => mockCollectionRepository.update(any())).called(1);
    });

    test('updateCollection rejects an invalid collection', () async {
      await expectLater(
        collectionService.updateCollection(_invalidCollection()),
        throwsFormatException,
      );
      verifyNever(() => mockCollectionRepository.update(any()));
    });
  });

  group('ProductService validation integration', () {
    test('addProduct persists a valid product', () async {
      final product = _validProduct();
      when(
        () => mockProductRepository.add(any()),
      ).thenAnswer((_) async => product);

      final added = await productService.addProduct(product);

      expect(added, product);
      verify(() => mockProductRepository.add(any())).called(1);
    });

    test('addProduct rejects an invalid product', () async {
      await expectLater(
        productService.addProduct(_invalidProduct()),
        throwsFormatException,
      );
      verifyNever(() => mockProductRepository.add(any()));
    });

    test('updateProduct persists a valid product', () async {
      when(() => mockProductRepository.update(any())).thenAnswer((_) async {});

      await productService.updateProduct(_validProduct());

      verify(() => mockProductRepository.update(any())).called(1);
    });

    test('updateProduct rejects an invalid product', () async {
      await expectLater(
        productService.updateProduct(_invalidProduct()),
        throwsFormatException,
      );
      verifyNever(() => mockProductRepository.update(any()));
    });
  });
}
