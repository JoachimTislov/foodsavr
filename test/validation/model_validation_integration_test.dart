import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart';
import 'package:foodsavr/interfaces/i_product_repository.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validation_error.dart';
import 'package:foodsavr/validation/validation_result.dart';
import 'package:foodsavr/validation/validators/collection_model_validator.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class MockICollectionRepository extends Mock
    implements ICollectionRepository {}

class MockIProductRepository extends Mock implements IProductRepository {}

class MockShelfLifeService extends Mock implements ShelfLifeService {}

class _FakeCollection extends Fake implements Collection {}

class _FakeProduct extends Fake implements Product {}

Collection buildCollection({String name = 'Pantry'}) {
  return Collection(
    id: 'c1',
    name: name,
    productIds: const [],
    userId: 'user-1',
    type: CollectionType.inventory,
  );
}

Product buildProduct({
  String name = 'Milk',
  int nonExpiringQuantity = 1,
  List<ExpiryEntry> expiries = const [],
}) {
  return Product(
    id: 'p1',
    name: name,
    description: 'Fresh dairy product',
    userId: 'user-1',
    nonExpiringQuantity: nonExpiringQuantity,
    expiries: expiries,
  );
}

void main() {
  late MockICollectionRepository mockCollectionRepository;
  late MockIProductRepository mockProductRepository;
  late MockShelfLifeService mockShelfLifeService;
  late CollectionService collectionService;
  late ProductService productService;

  setUpAll(() {
    registerFallbackValue(_FakeCollection());
    registerFallbackValue(_FakeProduct());
  });

  setUp(() {
    mockCollectionRepository = MockICollectionRepository();
    mockProductRepository = MockIProductRepository();
    mockShelfLifeService = MockShelfLifeService();
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

  group('model validators', () {
    test('CollectionModelValidator rejects empty and blank names', () {
      final validator = CollectionModelValidator();

      final empty = validator.validate(buildCollection(name: ''));
      expect(empty.isValid, isFalse);
      expect(empty.errors, hasLength(1));
      expect(empty.errors.first.field, 'name');

      final blank = validator.validate(buildCollection(name: '   '));
      expect(blank.isValid, isFalse);
    });

    test('CollectionModelValidator accepts a valid collection', () {
      final result = CollectionModelValidator().validate(buildCollection());

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('ProductModelValidator rejects an empty name', () {
      final result = ProductModelValidator().validate(
        buildProduct(name: ''),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.first.field, 'name');
    });

    test('ProductModelValidator rejects a negative quantity', () {
      final result = ProductModelValidator().validate(
        buildProduct(nonExpiringQuantity: -1),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.first.field, 'nonExpiringQuantity');
    });

    test('ProductModelValidator collects multiple errors', () {
      final result = ProductModelValidator().validate(
        buildProduct(name: '', nonExpiringQuantity: -1),
      );

      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(2));
    });

    test('ProductModelValidator rejects non-positive expiry quantities', () {
      final product = buildProduct(
        expiries: [
          ExpiryEntry(
            quantity: 0,
            expirationDate: DateTime(2030, 1, 1),
          ),
          ExpiryEntry(
            quantity: 2,
            expirationDate: DateTime(2030, 1, 2),
          ),
          ExpiryEntry(
            quantity: -3,
            expirationDate: DateTime(2030, 1, 3),
          ),
        ],
      );

      final result = ProductModelValidator().validate(product);

      expect(result.isValid, isFalse);
      expect(
        result.errors.map((error) => error.field).toList(),
        ['expiries[0].quantity', 'expiries[2].quantity'],
      );
    });

    test('ProductModelValidator accepts a valid product', () {
      final result = ProductModelValidator().validate(buildProduct());

      expect(result.isValid, isTrue);
    });
  });

  group('validation result and error values', () {
    test('success result is valid and compares equal', () {
      final result = ValidationResult.success();

      expect(result.isValid, isTrue);
      expect(result, ValidationResult.success());
      expect(result.toString(), contains('ValidationResult'));
    });

    test('failure result carries its error', () {
      const error = ValidationError(field: 'name', message: 'cannot be empty');
      final result = ValidationResult.failure(error);

      expect(result.isValid, isFalse);
      expect(result.errors.single, error);
      expect(result, ValidationResult.failure(error));
    });

    test('ValidationError supports equality and toString', () {
      const a = ValidationError(field: 'name', message: 'cannot be empty');
      const b = ValidationError(field: 'name', message: 'cannot be empty');
      const c = ValidationError(field: 'quantity', message: 'negative');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a.toString(), contains('name'));
    });
  });

  group('CollectionService integrates collection validation', () {
    test('addCollection rejects invalid collections without persisting', () async {
      await expectLater(
        () => collectionService.addCollection(buildCollection(name: '  ')),
        throwsFormatException,
      );

      verifyNever(() => mockCollectionRepository.add(any()));
    });

    test('addCollection persists a valid collection', () async {
      final valid = buildCollection();
      when(
        () => mockCollectionRepository.add(any()),
      ).thenAnswer((_) async => valid);

      final result = await collectionService.addCollection(valid);

      expect(result, valid);
      verify(() => mockCollectionRepository.add(valid)).called(1);
    });

    test('updateCollection rejects invalid collections without persisting', () async {
      await expectLater(
        () => collectionService.updateCollection(buildCollection(name: '')),
        throwsFormatException,
      );

      verifyNever(() => mockCollectionRepository.update(any()));
    });

    test('updateCollection persists a valid collection', () async {
      final valid = buildCollection();
      when(
        () => mockCollectionRepository.update(any()),
      ).thenAnswer((_) async {});

      await collectionService.updateCollection(valid);

      verify(() => mockCollectionRepository.update(valid)).called(1);
    });
  });

  group('ProductService integrates product validation', () {
    test('addProduct rejects an empty name without persisting', () async {
      await expectLater(
        () => productService.addProduct(buildProduct(name: '')),
        throwsFormatException,
      );

      verifyNever(() => mockProductRepository.add(any()));
    });

    test('addProduct rejects a negative quantity without persisting', () async {
      await expectLater(
        () => productService.addProduct(
          buildProduct(nonExpiringQuantity: -1),
        ),
        throwsFormatException,
      );

      verifyNever(() => mockProductRepository.add(any()));
    });

    test('addProduct rejects bad expiry quantities without persisting', () async {
      await expectLater(
        () => productService.addProduct(
          buildProduct(
            expiries: [
              ExpiryEntry(
                quantity: 0,
                expirationDate: DateTime(2030, 1, 1),
              ),
            ],
          ),
        ),
        throwsFormatException,
      );

      verifyNever(() => mockProductRepository.add(any()));
    });

    test('addProduct persists a valid product', () async {
      final valid = buildProduct();
      when(
        () => mockProductRepository.add(any()),
      ).thenAnswer((_) async => valid);

      final result = await productService.addProduct(valid);

      expect(result, valid);
      verify(() => mockProductRepository.add(valid)).called(1);
    });

    test('updateProduct rejects invalid products without persisting', () async {
      await expectLater(
        () => productService.updateProduct(buildProduct(name: ' ')),
        throwsFormatException,
      );

      verifyNever(() => mockProductRepository.update(any()));
    });

    test('updateProduct persists a valid product', () async {
      final valid = buildProduct();
      when(
        () => mockProductRepository.update(any()),
      ).thenAnswer((_) async {});

      await productService.updateProduct(valid);

      verify(() => mockProductRepository.update(valid)).called(1);
    });
  });
}
