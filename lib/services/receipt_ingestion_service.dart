import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:receipt_recognition/receipt_recognition.dart';

import '../models/product_model.dart';
import 'product_service.dart';

/// Converts a recognized supermarket receipt into inventory products.
@lazySingleton
class ReceiptIngestionService {
  final ProductService _productService;
  final Logger _logger;

  ReceiptIngestionService(this._productService, this._logger);

  /// Adds every recognized line item as a product for [userId].
  /// Returns the created products; throws only when every line item fails.
  Future<List<Product>> ingestReceipt(
    RecognizedReceipt receipt,
    String userId,
  ) async {
    final result = await ingestReceiptDetailed(receipt, userId);
    if (result.savedProducts.isEmpty && receipt.positions.isNotEmpty) {
      throw StateError(
        'Failed to save all ${receipt.positions.length} receipt items',
      );
    }
    if (result.failedItems > 0) {
      _logger.w(
        'Partial ingestion: saved ${result.savedProducts.length}, '
        'failed ${result.failedItems} receipt items',
      );
    }
    return result.savedProducts;
  }

  /// Adds every recognized line item and reports saved and failed items.
  Future<ReceiptIngestionResult> ingestReceiptDetailed(
    RecognizedReceipt receipt,
    String userId,
  ) async {
    final saved = <Product>[];
    var failed = 0;
    for (final position in receipt.positions) {
      final name = position.product.formattedValue.trim();
      if (name.isEmpty) continue;
      final quantity = _quantityFromPosition(position);
      final product = Product(
        id: '${DateTime.now().microsecondsSinceEpoch}-${saved.length}',
        name: name,
        description: '',
        userId: userId,
        nonExpiringQuantity: quantity,
      );
      try {
        saved.add(await _productService.addProduct(product));
      } catch (e) {
        failed++;
        _logger.e('Failed to add receipt line item "$name": $e');
      }
    }
    _logger.i('Ingested ${saved.length} products from receipt');
    return ReceiptIngestionResult(savedProducts: saved, failedItems: failed);
  }

  int _quantityFromPosition(RecognizedPosition position) {
    final quantity = position.unit?.quantity.value;
    if (quantity != null && quantity > 0) {
      return quantity;
    }
    return 1;
  }
}

/// Outcome of ingesting a receipt: which products were saved and how
/// many line items failed.
class ReceiptIngestionResult {
  const ReceiptIngestionResult({
    required this.savedProducts,
    required this.failedItems,
  });

  final List<Product> savedProducts;
  final int failedItems;
}
