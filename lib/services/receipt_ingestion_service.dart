import 'package:foodsavr_core/foodsavr_core.dart' show ShelfLifeInferer;
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:receipt_recognition/receipt_recognition.dart';

import '../controllers/preferences_controller.dart';
import '../interfaces/i_receipt_repository.dart';
import '../models/product_model.dart';
import '../models/receipt_record.dart';
import 'collection_service.dart';
import 'product_service.dart';

/// Converts a recognized supermarket receipt into inventory products.
///
/// Items land in a target inventory with an estimated expiry where the
/// shelf-life inferer knows the category, and each receipt is recorded so
/// ingesting it again adds nothing.
@lazySingleton
class ReceiptIngestionService {
  final ProductService _productService;
  final CollectionService _collectionService;
  final PreferencesController _preferences;
  final IReceiptRepository _receipts;
  final Logger _logger;
  // foodsavr_core is the shared inferer; the app-side ShelfLifeService is
  // keyed by Open Food Facts tags, which receipt lines do not have (#326).
  final ShelfLifeInferer _shelfLife = ShelfLifeInferer();

  ReceiptIngestionService(
    this._productService,
    this._collectionService,
    this._preferences,
    this._receipts,
    this._logger,
  );

  /// Adds every recognized line item as a product for [userId].
  /// Returns the created products (empty when the receipt was already
  /// added); throws only when every line item fails.
  Future<List<Product>> ingestReceipt(
    RecognizedReceipt receipt,
    String userId, {
    String? collectionId,
  }) async {
    final result = await ingestReceiptDetailed(
      receipt,
      userId,
      collectionId: collectionId,
    );
    if (result.alreadyAdded) return const [];
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

  /// Adds every recognized line item into [collectionId], or the user's
  /// default inventory when null, and reports saved and failed items.
  /// A receipt already ingested by [userId] adds nothing and reports
  /// [ReceiptIngestionResult.alreadyAdded].
  Future<ReceiptIngestionResult> ingestReceiptDetailed(
    RecognizedReceipt receipt,
    String userId, {
    String? collectionId,
  }) async {
    final receiptId = ReceiptRecord.idFor(receipt);
    if (await _alreadyAdded(userId, receiptId)) {
      _logger.i('Receipt $receiptId was already added');
      return const ReceiptIngestionResult(
        savedProducts: [],
        failedItems: 0,
        alreadyAdded: true,
      );
    }

    final target =
        collectionId ??
        await _preferences.resolveDefaultInventoryId(userId: userId);
    final now = DateTime.now();
    final saved = <Product>[];
    var failed = 0;
    for (final position in receipt.positions) {
      final name = position.product.formattedValue.trim();
      if (name.isEmpty) continue;
      final product = _productFor(position, name, userId, now);
      try {
        saved.add(await _productService.addProduct(product));
      } catch (e) {
        failed++;
        _logger.e('Failed to add receipt line item "$name": $e');
      }
    }

    if (saved.isNotEmpty) {
      final ids = saved.map((p) => p.id).toList();
      if (target != null) {
        await _collectionService.addProductsToCollection(target, ids);
      } else {
        _logger.w('No inventory to place ${ids.length} receipt items in');
      }
      await _record(
        userId,
        ReceiptRecord.from(
          receipt,
          productIds: ids,
          collectionId: target,
          now: now,
        ),
      );
    }
    _logger.i('Ingested ${saved.length} products from receipt');
    return ReceiptIngestionResult(
      savedProducts: saved,
      failedItems: failed,
      collectionId: target,
    );
  }

  /// Duplicate detection is best effort: when the record cannot be read (for
  /// example before the inbox rule is applied), the receipt is ingested.
  Future<bool> _alreadyAdded(String userId, String receiptId) async {
    try {
      return await _receipts.exists(userId, receiptId);
    } catch (e) {
      _logger.w('Could not check receipt $receiptId, ingesting it: $e');
      return false;
    }
  }

  /// Writes the idempotency record. A failure is logged, not thrown: the
  /// products are already placed, so the ingest itself succeeded.
  Future<void> _record(String userId, ReceiptRecord record) async {
    try {
      await _receipts.create(userId, record);
    } catch (e) {
      _logger.e('Failed to record receipt ${record.id}: $e');
    }
  }

  /// A product with an empty id (the repository assigns one). A known
  /// category gets an expiry entry counted from [now]; others stay
  /// non-expiring.
  Product _productFor(
    RecognizedPosition position,
    String name,
    String userId,
    DateTime now,
  ) {
    final quantity = _quantityFromPosition(position);
    final category = _shelfLife.categorize(name.toLowerCase());
    final days = category == null ? null : _shelfLife.defaultFor(category);
    return Product(
      id: '',
      name: name,
      description: '',
      userId: userId,
      expiries: days == null
          ? const []
          : [
              ExpiryEntry(
                quantity: quantity,
                expirationDate: now.add(Duration(days: days)),
              ),
            ],
      nonExpiringQuantity: days == null ? quantity : 0,
    );
  }

  int _quantityFromPosition(RecognizedPosition position) {
    final quantity = position.unit?.quantity.value;
    if (quantity != null && quantity > 0) {
      return quantity;
    }
    return 1;
  }
}

/// Outcome of ingesting a receipt: which products were saved, how many line
/// items failed, where they were placed, and whether the receipt had already
/// been added.
class ReceiptIngestionResult {
  const ReceiptIngestionResult({
    required this.savedProducts,
    required this.failedItems,
    this.collectionId,
    this.alreadyAdded = false,
  });

  final List<Product> savedProducts;
  final int failedItems;

  /// Inventory the products were added to; null when none was available.
  final String? collectionId;

  /// True when this receipt was ingested before and nothing was added.
  final bool alreadyAdded;
}
