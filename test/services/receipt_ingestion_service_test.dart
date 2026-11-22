import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_receipt_repository.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/models/receipt_record.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/services/receipt_ingestion_service.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:receipt_recognition/receipt_recognition.dart';
import 'package:receipt_recognition/src/services/ocr/receipt_text_line.dart';

class _MockProductService extends Mock implements ProductService {}

class _MockCollectionService extends Mock implements CollectionService {}

class _MockPreferences extends Mock implements PreferencesController {}

class _FakeProduct extends Fake implements Product {}

class _InMemoryReceiptRepository implements IReceiptRepository {
  final Map<String, ReceiptRecord> records = {};

  @override
  Future<bool> exists(String userId, String receiptId) async =>
      records.containsKey('$userId/$receiptId');

  @override
  Future<bool> create(String userId, ReceiptRecord record) async {
    final key = '$userId/${record.id}';
    if (records.containsKey(key)) return false;
    records[key] = record;
    return true;
  }
}

class _FailingReceiptRepository implements IReceiptRepository {
  @override
  Future<bool> exists(String userId, String receiptId) async =>
      throw Exception('permission-denied');

  @override
  Future<bool> create(String userId, ReceiptRecord record) async =>
      throw Exception('permission-denied');
}

RecognizedPosition _position(String name, {double price = 1.0}) {
  return RecognizedPosition(
    product: RecognizedProduct(line: const ReceiptTextLine(), value: name),
    price: RecognizedPrice(line: const ReceiptTextLine(), value: price),
    timestamp: DateTime.now(),
    operation: Operation.none,
  );
}

RecognizedReceipt _receipt(List<RecognizedPosition> positions) {
  return RecognizedReceipt(
    positions: positions,
    timestamp: DateTime.now(),
    store: const RecognizedStore(value: 'Rema 1000', line: ReceiptTextLine()),
  );
}

void main() {
  late _MockProductService productService;
  late _MockCollectionService collectionService;
  late _MockPreferences preferences;
  late _InMemoryReceiptRepository receipts;
  late ReceiptIngestionService service;
  late List<Product> created;
  var nextId = 0;

  setUpAll(() {
    registerFallbackValue(_FakeProduct());
  });

  setUp(() {
    nextId = 0;
    created = [];
    productService = _MockProductService();
    collectionService = _MockCollectionService();
    preferences = _MockPreferences();
    receipts = _InMemoryReceiptRepository();
    service = ReceiptIngestionService(
      productService,
      collectionService,
      preferences,
      receipts,
      Logger(),
    );
    // Mirrors ProductRepository: an empty id is replaced by a generated one.
    when(() => productService.addProduct(any())).thenAnswer((invocation) async {
      final product = invocation.positionalArguments[0] as Product;
      final saved = product.id.isEmpty
          ? product.copyWith(id: 'generated-${nextId++}')
          : product;
      created.add(saved);
      return saved;
    });
    when(
      () => collectionService.addProductsToCollection(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => preferences.resolveDefaultInventoryId(userId: any(named: 'userId')),
    ).thenAnswer((_) async => 'default-inv');
  });

  test('returns created products when every line item is saved', () async {
    final products = await service.ingestReceipt(
      _receipt([_position('Milk'), _position('Bread')]),
      'user-1',
    );

    expect(products.length, 2);
  });

  test('throws when saving a line item fails', () async {
    when(
      () => productService.addProduct(any()),
    ).thenThrow(Exception('storage write failed'));

    expect(
      () => service.ingestReceipt(
        _receipt([_position('Milk'), _position('Bread')]),
        'user-1',
      ),
      throwsStateError,
    );
  });

  test('creates products with an empty id for the repository to assign', () {
    final receipt = _receipt([_position('Milk')]);
    return service.ingestReceipt(receipt, 'user-1').then((_) {
      final captured = verify(
        () => productService.addProduct(captureAny()),
      ).captured.cast<Product>();
      expect(captured.single.id, isEmpty);
    });
  });

  group('placement', () {
    test('adds every created product id to the explicit collection', () async {
      final result = await service.ingestReceiptDetailed(
        _receipt([_position('Milk'), _position('Bread'), _position('Soap')]),
        'user-1',
        collectionId: 'inv-1',
      );

      expect(result.collectionId, 'inv-1');
      final added =
          verify(
                () => collectionService.addProductsToCollection(
                  'inv-1',
                  captureAny(),
                ),
              ).captured.single
              as List<String>;
      expect(added, created.map((p) => p.id).toList());
      expect(added.length, 3);
      verifyNever(
        () =>
            preferences.resolveDefaultInventoryId(userId: any(named: 'userId')),
      );
    });

    test('falls back to the default inventory without a collection', () async {
      final result = await service.ingestReceiptDetailed(
        _receipt([_position('Milk')]),
        'user-1',
      );

      expect(result.collectionId, 'default-inv');
      verify(
        () => collectionService.addProductsToCollection('default-inv', [
          'generated-0',
        ]),
      ).called(1);
    });

    test('keeps products standalone when the user has no inventory', () async {
      when(
        () =>
            preferences.resolveDefaultInventoryId(userId: any(named: 'userId')),
      ).thenAnswer((_) async => null);

      final result = await service.ingestReceiptDetailed(
        _receipt([_position('Milk')]),
        'user-1',
      );

      expect(result.collectionId, isNull);
      expect(result.savedProducts.length, 1);
      verifyNever(
        () => collectionService.addProductsToCollection(any(), any()),
      );
    });
  });

  group('expiry', () {
    test(
      'known categories get an estimated expiry, others stay open',
      () async {
        final before = DateTime.now();
        await service.ingestReceiptDetailed(
          _receipt([
            _position('Melk 1L'),
            _position('Brød'),
            _position('Soap'),
          ]),
          'user-1',
          collectionId: 'inv-1',
        );

        final milk = created.firstWhere((p) => p.name == 'Melk 1L');
        final bread = created.firstWhere((p) => p.name == 'Brød');
        final soap = created.firstWhere((p) => p.name == 'Soap');

        expect(milk.expiries.single.quantity, 1);
        expect(milk.nonExpiringQuantity, 0);
        expect(
          milk.expiries.single.expirationDate.difference(before).inDays,
          inInclusiveRange(6, 7),
        );
        expect(
          bread.expiries.single.expirationDate.difference(before).inDays,
          inInclusiveRange(3, 4),
        );
        expect(soap.expiries, isEmpty);
        expect(soap.nonExpiringQuantity, 1);
      },
    );
  });

  group('idempotency', () {
    test('the same receipt twice adds the items once', () async {
      final receipt = _receipt([_position('Milk'), _position('Bread')]);

      final first = await service.ingestReceiptDetailed(
        receipt,
        'user-1',
        collectionId: 'inv-1',
      );
      final second = await service.ingestReceiptDetailed(
        receipt,
        'user-1',
        collectionId: 'inv-1',
      );

      expect(first.alreadyAdded, isFalse);
      expect(second.alreadyAdded, isTrue);
      expect(second.savedProducts, isEmpty);
      expect(created.length, 2);
      verify(
        () => collectionService.addProductsToCollection('inv-1', any()),
      ).called(1);
      expect(receipts.records.length, 1);
    });

    test('a rescan with the same lines is the same receipt', () async {
      await service.ingestReceipt(
        _receipt([_position('Milk'), _position('Bread')]),
        'user-1',
      );
      final again = await service.ingestReceiptDetailed(
        _receipt([_position('Milk'), _position('Bread')]),
        'user-1',
      );

      expect(again.alreadyAdded, isTrue);
      expect(created.length, 2);
    });

    test('ingestReceipt does not throw for an already added receipt', () async {
      final receipt = _receipt([_position('Milk')]);
      await service.ingestReceipt(receipt, 'user-1');

      expect(await service.ingestReceipt(receipt, 'user-1'), isEmpty);
    });

    test('a different receipt is added', () async {
      await service.ingestReceipt(_receipt([_position('Milk')]), 'user-1');
      final other = await service.ingestReceiptDetailed(
        _receipt([_position('Milk'), _position('Eggs')]),
        'user-1',
      );

      expect(other.alreadyAdded, isFalse);
      expect(created.length, 3);
    });

    test('another user can add the same receipt', () async {
      final receipt = _receipt([_position('Milk')]);
      await service.ingestReceipt(receipt, 'user-1');
      final other = await service.ingestReceiptDetailed(receipt, 'user-2');

      expect(other.alreadyAdded, isFalse);
    });

    test('a failed ingest records nothing so the user can retry', () async {
      when(
        () => productService.addProduct(any()),
      ).thenThrow(Exception('storage write failed'));
      final receipt = _receipt([_position('Milk')]);

      await expectLater(
        service.ingestReceipt(receipt, 'user-1'),
        throwsStateError,
      );

      expect(receipts.records, isEmpty);
    });
  });

  group('record unavailable', () {
    test(
      'still places the items when the record cannot be read or written',
      () async {
        final failing = ReceiptIngestionService(
          productService,
          collectionService,
          preferences,
          _FailingReceiptRepository(),
          Logger(level: Level.off),
        );

        final result = await failing.ingestReceiptDetailed(
          _receipt([_position('Milk'), _position('Bread')]),
          'user-1',
          collectionId: 'inv-1',
        );

        expect(result.alreadyAdded, isFalse);
        expect(result.savedProducts.length, 2);
        verify(
          () => collectionService.addProductsToCollection('inv-1', [
            'generated-0',
            'generated-1',
          ]),
        ).called(1);
      },
    );
  });

  group('ReceiptRecord keys', () {
    test('follows ADR 0005: receipt:<store>:<hash>', () {
      final key = ReceiptRecord.idFor(_receipt([_position('Milk')]));

      expect(key, matches(RegExp(r'^receipt:rema-1000:[0-9a-f]{32}$')));
    });

    test('uses app when no store was recognized', () {
      final key = ReceiptRecord.idFor(
        RecognizedReceipt(
          positions: [_position('Milk')],
          timestamp: DateTime.now(),
        ),
      );

      expect(key, startsWith('receipt:app:'));
    });

    test('differs when the positions differ', () {
      expect(
        ReceiptRecord.idFor(_receipt([_position('Milk')])),
        isNot(ReceiptRecord.idFor(_receipt([_position('Bread')]))),
      );
    });
  });
}
