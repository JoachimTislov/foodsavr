import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validation_error.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:logger/logger.dart';

import '../support/fake_product_repository.dart';

void main() {
  const milk = Product(
    id: 'p1',
    name: 'Milk',
    description: '',
    userId: 'user-1',
    barcode: '0000000999001',
  );

  ProductService serviceFor(FakeProductRepository repository) => ProductService(
    repository,
    ProductModelValidator(),
    ShelfLifeService(),
    Logger(level: Level.off),
  );

  test('addExpiry stores the merged expiry and refreshes the cache', () async {
    final repository = FakeProductRepository([milk]);
    final service = serviceFor(repository);
    await service.getProducts('user-1');

    final date = DateTime(2027, 3, 4);
    await service.addExpiry('p1', date, quantity: 2);
    await service.addExpiry('p1', date);

    final stored = repository.updated.last;
    expect(stored.expiries.single.quantity, 3);
    expect((await service.getProducts('user-1')).single.quantity, 3);
  });

  test('addExpiry rejects a quantity that is not positive', () async {
    final repository = FakeProductRepository([milk]);

    expect(
      serviceFor(repository).addExpiry('p1', DateTime(2027), quantity: 0),
      throwsA(isA<ValidationException>()),
    );
    expect(repository.updated, isEmpty);
  });

  test('findOwnedByBarcode matches padded and exact barcodes', () async {
    final service = serviceFor(FakeProductRepository([milk]));

    expect((await service.findOwnedByBarcode('user-1', '999001'))?.id, 'p1');
    expect(await service.findOwnedByBarcode('user-1', '123'), isNull);
    expect(await service.findOwnedByBarcode('other', '999001'), isNull);
  });
}
