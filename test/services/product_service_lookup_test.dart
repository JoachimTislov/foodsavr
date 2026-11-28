import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:logger/logger.dart';

import '../support/fake_open_food_facts.dart';
import '../support/fake_product_repository.dart';

void main() {
  late FakeOpenFoodFacts openFoodFacts;
  late FakeProductRepository repository;
  late ProductService service;

  setUp(() {
    openFoodFacts = FakeOpenFoodFacts();
    repository = FakeProductRepository([
      const Product(
        id: 'owned',
        name: 'Home jam',
        description: '',
        userId: 'user',
        barcode: '0000000004242',
      ),
    ]);
    service = ProductService(
      repository,
      ProductModelValidator(),
      ShelfLifeService(),
      Logger(level: Level.off),
      offClient: openFoodFacts.client,
    );
  });

  Future<ProductLookupResult> lookUp(String barcode) =>
      service.lookupByBarcode(userId: 'user', barcode: barcode);

  test('an owned barcode is found without asking Open Food Facts', () async {
    final result = await lookUp('4242');

    expect(result.owned, isTrue);
    expect(openFoodFacts.lookups, isEmpty);
    expect(repository.writes, 0);
  });

  test('a known barcode previews without saving, and is asked once', () async {
    openFoodFacts.known['7038010009457'] = 'Lettmelk';

    final result = await lookUp('7038010009457');
    expect(result.exact, isTrue);
    expect(result.candidates.single.name, 'Lettmelk');
    expect(repository.writes, 0);

    final added = await service.addOrIncrementByBarcode(
      userId: 'user',
      barcode: '7038010009457',
    );
    expect(added.product.name, 'Lettmelk');
    expect(openFoodFacts.lookups, ['7038010009457']);
  });

  test('an unknown barcode lists partial matches', () async {
    openFoodFacts.searchable = ['Candidate A', 'Candidate B'];

    final result = await lookUp('96385074');

    expect(result.exact, isFalse);
    expect(result.candidates.map((p) => p.name), openFoodFacts.searchable);
    expect(openFoodFacts.searches, ['96385074']);
    expect(repository.writes, 0);
  });

  test('offline is reported, not mistaken for no match', () async {
    openFoodFacts.offline = true;

    expect((await lookUp('96385074')).offline, isTrue);
    expect((await service.searchCatalog('melk')).offline, isTrue);
  });

  test('categoryForTags prefers the most specific known tag', () {
    const expected = {
      ['en:dairies', 'en:milks']: 'dairy',
      ['en:breads']: 'bakery',
      ['en:fruits-and-vegetables-based-foods', 'en:fresh-vegetables']:
          'vegetables',
      ['en:canned-foods']: 'pantry',
      ['en:fresh-fruits']: 'fruits',
      ['en:beverages', 'en:organic']: null,
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      expect(ProductService.categoryForTags(key), value, reason: '$key');
    }
  });
}
