import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_validator.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/barcode_lookup_queue.dart';
import 'package:foodsavr/services/open_food_facts_client.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validation_result.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_product_repository.dart';

class _MockValidator extends Mock implements IValidator<Product> {}

class _MockShelfLife extends Mock implements ShelfLifeService {}

class _FakeProduct extends Fake implements Product {}

/// Open Food Facts stand-in whose reachability the test switches.
class _FakeOffClient extends Fake implements OpenFoodFactsClient {
  OffLookup next = const OffOffline();
  final List<String> lookups = [];

  @override
  Future<OffLookup> lookup(String barcode, {String languageCode = 'nb'}) async {
    lookups.add(barcode);
    return next;
  }
}

void main() {
  late FakeProductRepository repository;
  late _FakeOffClient offClient;
  late BarcodeLookupQueue queue;
  late ProductService service;

  setUpAll(() => registerFallbackValue(_FakeProduct()));

  setUp(() {
    final validator = _MockValidator();
    when(
      () => validator.validate(any()),
    ).thenReturn(ValidationResult.success());
    final shelfLife = _MockShelfLife();
    when(() => shelfLife.estimateExpiration(any())).thenReturn(null);
    repository = FakeProductRepository();
    offClient = _FakeOffClient();
    queue = BarcodeLookupQueue.memory();
    service = ProductService(
      repository,
      validator,
      shelfLife,
      Logger(level: Level.off),
      offClient: offClient,
      lookupQueue: queue,
    );
  });

  const found = OffFound(
    OffProductData(
      name: 'Milk',
      imageUrl: 'https://example.com/milk.png',
      tags: ['en:dairies'],
    ),
  );

  test('an offline scan saves the barcode and queues its lookup', () async {
    final result = await service.addOrIncrementByBarcode(
      userId: 'u1',
      barcode: '123456',
      languageCode: 'en',
    );

    expect(result.offline, isTrue);
    expect(result.notFound, isFalse);
    expect(result.product.id, isNotEmpty);
    expect(result.product.barcode, '0000000123456');
    expect(repository.added, hasLength(1));
    expect(queue.entries, [
      QueuedBarcodeLookup(
        productId: result.product.id,
        barcode: '0000000123456',
        languageCode: 'en',
      ),
    ]);
  });

  test('replay keeps the queue while still offline', () async {
    await service.addOrIncrementByBarcode(userId: 'u1', barcode: '123456');

    expect(await service.replayQueuedLookups(), 0);
    expect(queue.length, 1);
    expect(repository.updated, isEmpty);
  });

  test('replay after reconnecting fills in the placeholder product', () async {
    final scanned = await service.addOrIncrementByBarcode(
      userId: 'u1',
      barcode: '123456',
    );
    offClient.next = found;

    expect(await service.replayQueuedLookups(), 1);

    expect(queue.length, 0);
    final product = (await repository.get(scanned.product.id))!;
    expect(product.name, 'Milk');
    expect(product.imageUrl, 'https://example.com/milk.png');
    expect(product.tags, contains('en:dairies'));
    expect(product.nonExpiringQuantity, 1);
  });

  test('replay leaves a placeholder the user renamed meanwhile', () async {
    final scanned = await service.addOrIncrementByBarcode(
      userId: 'u1',
      barcode: '123456',
    );
    await repository.update(scanned.product.copyWith(name: 'My milk'));
    offClient.next = found;

    expect(await service.replayQueuedLookups(), 0);
    expect(queue.length, 0);
    expect((await repository.get(scanned.product.id))!.name, 'My milk');
  });

  test('replay drops a lookup Open Food Facts does not know', () async {
    await service.addOrIncrementByBarcode(userId: 'u1', barcode: '123456');
    offClient.next = const OffNotFound();

    expect(await service.replayQueuedLookups(), 0);
    expect(queue.length, 0);
  });

  test('an unknown barcode online is still notFound', () async {
    offClient.next = const OffNotFound();

    final result = await service.addOrIncrementByBarcode(
      userId: 'u1',
      barcode: '123456',
    );

    expect(result.notFound, isTrue);
    expect(result.offline, isFalse);
    expect(repository.added, isEmpty);
    expect(queue.length, 0);
  });
}
