import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_validator.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validation_error.dart';
import 'package:foodsavr/validation/validation_result.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_product_repository.dart';

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

class _RejectAllValidator implements IValidator<Product> {
  @override
  ValidationResult validate(Product instance) => ValidationResult.failure(
    const ValidationError(field: 'name', message: 'rejected'),
  );
}

ProductService _service(
  FakeProductRepository repository, {
  IValidator<Product>? validator,
}) {
  final shelfLife = _MockShelfLifeService();
  when(() => shelfLife.estimateExpiration(any())).thenReturn(null);
  return ProductService(
    repository,
    validator ?? ProductModelValidator(),
    shelfLife,
    Logger(level: Level.off),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const Product(id: 'x', name: 'x', description: '', userId: 'u'),
    );
  });

  const scannedDraft = Product(
    id: '',
    name: 'Oat drink',
    description: '',
    userId: 'user-1',
    nonExpiringQuantity: 1,
    barcode: '0000000999001',
  );

  group('scenario A: unknown barcode, manual entry', () {
    test(
      'not-found result carries the scanned barcode and writes nothing',
      () async {
        final repository = FakeProductRepository();
        final result = await _service(
          repository,
        ).addOrIncrementByBarcode(userId: 'user-1', barcode: '999001');

        expect(result.notFound, isTrue);
        expect(result.product.barcode, '0000000999001');
        expect(result.product.id, isNot('0'));
        expect(repository.writes, 0);
      },
    );

    test(
      'createProduct saves the prefilled draft with a generated id',
      () async {
        final repository = FakeProductRepository();

        final saved = await _service(repository).createProduct(scannedDraft);

        expect(saved.id, isNotEmpty);
        expect(saved.barcode, '0000000999001');
        expect(repository.added.single.id, saved.id);
        expect(repository.updated, isEmpty);
      },
    );

    test(
      'the saved product is matched by the next scan of that barcode',
      () async {
        final repository = FakeProductRepository();
        final service = _service(repository);
        final saved = await service.createProduct(scannedDraft);

        final rescan = await service.addOrIncrementByBarcode(
          userId: 'user-1',
          barcode: '999001',
        );

        expect(rescan.matchedExisting, isTrue);
        expect(rescan.product.id, saved.id);
        expect(repository.added, hasLength(1));
      },
    );

    test(
      'with a personal template both products get distinct generated ids',
      () async {
        final repository = FakeProductRepository();

        final saved = await _service(
          repository,
        ).createProduct(scannedDraft, withPersonalTemplate: true);

        expect(repository.added, hasLength(2));
        final personal = repository.added.first;
        expect(personal.registryType, 'personal');
        expect(personal.id, isNot(saved.id));
        expect(saved.registryType, 'current');
        expect(saved.mappedFromProductId, personal.id);
        expect(saved.barcode, '0000000999001');
      },
    );
  });

  group('scenario B: edit and rescan', () {
    final known = Product(
      id: 'p1',
      name: 'Milk',
      description: '',
      userId: 'user-1',
      nonExpiringQuantity: 1,
      barcode: '0000001234567',
      imageUrl: 'https://img/milk.png',
      tags: const ['en:organic'],
      registryType: 'current',
      mappedFromProductId: 'personal-1',
    );

    test('increment keeps registryType and mappedFromProductId', () async {
      final repository = FakeProductRepository([known]);

      await _service(
        repository,
      ).addOrIncrementByBarcode(userId: 'user-1', barcode: '1234567');

      final updated = repository.updated.single;
      expect(updated.nonExpiringQuantity, 2);
      expect(updated.registryType, 'current');
      expect(updated.mappedFromProductId, 'personal-1');
      expect(updated.imageUrl, known.imageUrl);
      expect(updated.tags, known.tags);
      expect(updated.barcode, known.barcode);
    });
  });

  group('failed validation performs no write', () {
    final known = Product(
      id: 'p1',
      name: 'Milk',
      description: '',
      userId: 'user-1',
      barcode: '0000001234567',
    );

    test('createProduct', () async {
      final repository = FakeProductRepository();
      await expectLater(
        _service(
          repository,
          validator: _RejectAllValidator(),
        ).createProduct(scannedDraft, withPersonalTemplate: true),
        throwsFormatException,
      );
      expect(repository.writes, 0);
    });

    test('updateProduct', () async {
      final repository = FakeProductRepository([known]);
      await expectLater(
        _service(
          repository,
          validator: _RejectAllValidator(),
        ).updateProduct(known.copyWith(name: '')),
        throwsFormatException,
      );
      expect(repository.writes, 0);
    });

    test('barcode increment', () async {
      final repository = FakeProductRepository([known]);
      await expectLater(
        _service(
          repository,
          validator: _RejectAllValidator(),
        ).addOrIncrementByBarcode(userId: 'user-1', barcode: '1234567'),
        throwsFormatException,
      );
      expect(repository.writes, 0);
    });
  });
}
