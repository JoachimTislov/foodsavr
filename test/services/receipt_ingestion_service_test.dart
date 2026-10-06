import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/services/receipt_ingestion_service.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:receipt_recognition/receipt_recognition.dart';
import 'package:receipt_recognition/src/services/ocr/receipt_text_line.dart';

class _MockProductService extends Mock implements ProductService {}

class _FakeProduct extends Fake implements Product {}

RecognizedPosition _position(String name) {
  return RecognizedPosition(
    product: RecognizedProduct(line: const ReceiptTextLine(), value: name),
    price: RecognizedPrice(line: const ReceiptTextLine(), value: 1.0),
    timestamp: DateTime.now(),
    operation: Operation.none,
  );
}

void main() {
  late _MockProductService mockProductService;
  late ReceiptIngestionService service;

  setUpAll(() {
    registerFallbackValue(_FakeProduct());
  });

  setUp(() {
    mockProductService = _MockProductService();
    service = ReceiptIngestionService(mockProductService, Logger());
  });

  test('returns created products when every line item is saved', () async {
    final receipt = RecognizedReceipt(
      positions: [_position('Milk'), _position('Bread')],
      timestamp: DateTime.now(),
    );
    when(() => mockProductService.addProduct(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments[0] as Product,
    );

    final products = await service.ingestReceipt(receipt, 'user-1');

    expect(products.length, 2);
  });

  test('throws when saving a line item fails', () async {
    final receipt = RecognizedReceipt(
      positions: [_position('Milk'), _position('Bread')],
      timestamp: DateTime.now(),
    );
    when(
      () => mockProductService.addProduct(any()),
    ).thenThrow(Exception('storage write failed'));

    expect(() => service.ingestReceipt(receipt, 'user-1'), throwsStateError);
  });
}
