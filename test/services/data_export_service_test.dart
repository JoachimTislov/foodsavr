import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/data_export_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:mocktail/mocktail.dart';

class _Collections extends Mock implements CollectionService {}

class _Products extends Mock implements ProductService {}

const _userId = 'user-1';

const _fridge = Collection(
  id: 'fridge',
  name: 'Kjøleskåp',
  userId: _userId,
  productIds: ['milk', 'gone', 'cheese'],
);
const _weekend = Collection(
  id: 'weekend',
  name: 'Helg, hytta',
  userId: _userId,
  productIds: ['bread'],
  type: CollectionType.shoppingList,
);
const _empty = Collection(
  id: 'empty',
  name: 'Bod',
  userId: _userId,
  productIds: [],
);

final _milk = Product(
  id: 'milk',
  name: 'Lettmelk "1,0 %"',
  description: 'Æ ø å\nandre linje',
  userId: _userId,
  category: 'dairy',
  barcode: '0007038010000',
  nonExpiringQuantity: 1,
  expiries: [ExpiryEntry(quantity: 2, expirationDate: DateTime(2026, 12, 3))],
);
const _cheese = Product(
  id: 'cheese',
  name: '=HYPERLINK("x")',
  description: '',
  userId: _userId,
);
const _bread = Product(
  id: 'bread',
  name: 'Brød',
  description: '',
  userId: _userId,
  nonExpiringQuantity: 3,
);
const _template = Product(
  id: 'template',
  name: 'Egg',
  description: '',
  userId: _userId,
  registryType: 'personal',
);

const _header =
    'section,collection_name,collection_type,product_name,category,barcode,'
    'quantity,expiration_date,notes\r\n';
const _milkFields = '"Lettmelk ""1,0 %""",dairy,0007038010000';
const _fridgeRows =
    'inventory,Kjøleskåp,inventory,$_milkFields,2,2026-12-03,'
    '"Æ ø å\nandre linje"\r\n'
    'inventory,Kjøleskåp,inventory,$_milkFields,1,,'
    '"Æ ø å\nandre linje"\r\n'
    'inventory,Kjøleskåp,inventory,"\'=HYPERLINK(""x"")",,,0,,\r\n';
const _weekendRow = 'shopping_list,"Helg, hytta",shoppingList,Brød,,,3,,\r\n';

void main() {
  late _Collections collections;
  late _Products products;
  late List<ExportFile> saved;
  late DataExportService service;

  setUp(() {
    collections = _Collections();
    products = _Products();
    saved = [];
    when(
      () => collections.getCollectionsForUser(_userId),
    ).thenAnswer((_) async => [_fridge, _weekend, _empty]);
    when(
      () => products.getProducts(_userId, forceRefresh: true),
    ).thenAnswer((_) async => [_milk, _cheese, _bread]);
    when(
      () => products.getPersonalProducts(_userId),
    ).thenAnswer((_) async => [_template]);
    service = DataExportService(
      collections,
      products,
      sink: (file) async {
        saved.add(file);
        return true;
      },
      clock: () => DateTime.utc(2026, 11, 28, 12),
    );
  });

  test('exports everything as CSV with a byte order mark by default', () async {
    final (:file, :delivered) = await service.export(userId: _userId);

    expect(delivered, isTrue);
    expect(saved, [file]);
    expect(file.fileName, 'foodsavr-export-2026-11-28.csv');
    expect(file.format, ExportFormat.csv);
    expect(file.bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(
      file.content,
      '\uFEFF$_header$_fridgeRows$_weekendRow'
      'inventory,Bod,inventory,,,,,,\r\n'
      'products,,products,$_milkFields,2,2026-12-03,"Æ ø å\nandre linje"\r\n'
      'products,,products,$_milkFields,1,,"Æ ø å\nandre linje"\r\n'
      'products,,products,"\'=HYPERLINK(""x"")",,,0,,\r\n'
      'products,,products,Brød,,,3,,\r\n'
      'saved_products,,products,Egg,,,0,,\r\n',
    );
    expect(utf8.decode(file.bytes), contains('Kjøleskåp'));
  });

  test('exports one collection without the products catalog', () async {
    final file = await service.build(
      userId: _userId,
      selection: const ExportSelection(collectionIds: {'weekend'}),
    );

    expect(file.content, '\uFEFF$_header$_weekendRow');
  });

  test('exports some collections together with the products', () async {
    final file = await service.build(
      userId: _userId,
      selection: const ExportSelection(
        collectionIds: {'fridge'},
        includeProducts: true,
      ),
    );

    expect(file.content, startsWith('\uFEFF$_header$_fridgeRows'));
    expect(file.content, isNot(contains('shopping_list')));
    expect(file.content, contains('\r\nsaved_products,'));
  });

  test('exports only the products catalog', () async {
    final file = await service.build(
      userId: _userId,
      selection: const ExportSelection(includeProducts: true),
    );

    expect(file.content, isNot(contains('inventory')));
    expect(file.content, contains('\r\nproducts,,products,Brød,,,3,,\r\n'));
  });

  test('exports pretty-printed JSON without user IDs', () async {
    final file = await service.build(
      userId: _userId,
      format: ExportFormat.json,
    );

    expect(file.fileName, 'foodsavr-export-2026-11-28.json');
    expect(file.content, startsWith('{\n  "application": "foodsavr",'));
    expect(file.content, isNot(contains(_userId)));
    final data = jsonDecode(file.content) as Map<String, dynamic>;
    expect(data['formatVersion'], 1);
    expect(data['exportedAt'], '2026-11-28T12:00:00.000Z');
    final exported = (data['collections'] as List).cast<Map>();
    expect(exported.map((c) => c['id']), ['fridge', 'weekend', 'empty']);
    final fridgeProducts = (exported.first['products'] as List).cast<Map>();
    // The dangling ID is left out; values are exact, formulas included.
    expect(fridgeProducts.map((p) => p['name']), [_milk.name, _cheese.name]);
    expect(fridgeProducts.first['expiries'], [
      {'quantity': 2, 'expirationDate': '2026-12-03T00:00:00.000'},
    ]);
    expect(data['products'], hasLength(3));
    expect(data['savedProducts'], hasLength(1));
  });

  test('a JSON export of one list has no product sections', () async {
    final file = await service.build(
      userId: _userId,
      selection: const ExportSelection(collectionIds: {'empty'}),
      format: ExportFormat.json,
    );

    final data = jsonDecode(file.content) as Map<String, dynamic>;
    expect(data.containsKey('products'), isFalse);
    expect(data.containsKey('savedProducts'), isFalse);
    expect(data['collections'], hasLength(1));
  });

  test('fails when a selected collection no longer exists', () async {
    await expectLater(
      service.export(
        userId: _userId,
        selection: const ExportSelection(collectionIds: {'deleted'}),
      ),
      throwsStateError,
    );
    expect(saved, isEmpty);
  });

  test('rejects an empty selection', () async {
    await expectLater(
      service.build(userId: _userId, selection: const ExportSelection()),
      throwsArgumentError,
    );
  });

  test('reports when the platform cannot save the file', () async {
    final unsupported = DataExportService(
      collections,
      products,
      sink: (_) async => false,
    );

    final (:file, :delivered) = await unsupported.export(userId: _userId);

    expect(delivered, isFalse);
    expect(file.content, contains('Kjøleskåp'));
  });

  test('the default sink does not deliver outside the browser', () async {
    final result = await DataExportService(
      collections,
      products,
    ).export(userId: _userId);

    expect(result.delivered, isFalse);
  });

  test('escapes CSV fields as RFC 4180 requires', () {
    const cases = {
      'plain': 'plain',
      'a,b': '"a,b"',
      'say "hi"': '"say ""hi"""',
      'two\nlines': '"two\nlines"',
      'carriage\rreturn': '"carriage\rreturn"',
      ' padded ': '" padded "',
      '+SUM(A1)': "'+SUM(A1)",
      '@cmd': "'@cmd",
      '-2+3': "'-2+3",
      '-18': '-18',
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      expect(DataExportService.escapeCsvField(key), value, reason: key);
    }
  });
}
