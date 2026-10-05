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
  /// Returns the created products.
  Future<List<Product>> ingestReceipt(
    RecognizedReceipt receipt,
    String userId,
  ) async {
    final products = <Product>[];
    for (final position in receipt.positions) {
      final name = position.product.formattedValue.trim();
      if (name.isEmpty) continue;
      final quantity = _quantityFromPosition(position);
      final product = Product(
        id: '${DateTime.now().microsecondsSinceEpoch}-${products.length}',
        name: name,
        description: '',
        userId: userId,
        nonExpiringQuantity: quantity,
      );
      try {
        products.add(await _productService.addProduct(product));
      } catch (e) {
        _logger.e('Failed to add receipt line item "$name": $e');
      }
    }
    _logger.i('Ingested ${products.length} products from receipt');
    return products;
  }

  int _quantityFromPosition(RecognizedPosition position) {
    final quantity = position.unit?.quantity.value;
    if (quantity != null && quantity > 0) {
      return quantity;
    }
    return 1;
  }
}
