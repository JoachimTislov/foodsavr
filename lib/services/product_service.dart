import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:foodsavr/interfaces/i_validator.dart';
import 'package:foodsavr/validation/validation_error.dart';

import '../constants/preferences_config.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../interfaces/i_product_repository.dart';
import '../utils/shelf_life.dart';
import 'barcode_lookup_queue.dart';
import 'open_food_facts_client.dart';

@lazySingleton
class ProductService {
  static const _cacheTtl = Duration(minutes: 2);

  final IProductRepository _productRepository;
  final IValidator<Product> _productValidator;
  final ShelfLifeService _shelfLifeService;
  final Logger _logger;
  final OpenFoodFactsClient _offClient;
  final BarcodeLookupQueue _lookupQueue;

  final Map<String, (DateTime, List<Product>)> _productsCache = {};
  final Map<String, int> _fetchSequence = {};
  final Map<String, Future<List<Product>>> _pendingFetches = {};
  int _cacheGeneration = 0;

  ProductService(
    this._productRepository,
    this._productValidator,
    this._shelfLifeService,
    this._logger, {
    OpenFoodFactsClient? offClient,
    BarcodeLookupQueue? lookupQueue,
  }) : _offClient = offClient ?? OpenFoodFactsClient(_logger),
       _lookupQueue = lookupQueue ?? BarcodeLookupQueue.memory();

  void _invalidateCache() {
    _productsCache.clear();
    _pendingFetches.clear();
    _cacheGeneration++;
  }

  String _normalizeBarcode(String barcode) {
    var normalized = barcode.trim();
    if (normalized.length < 13) {
      normalized = normalized.padLeft(13, '0');
    }
    return normalized;
  }

  Future<ScanAddProductResult> addOrIncrementByBarcode({
    required String userId,
    required String barcode,
    String languageCode = 'nb',
  }) async {
    _logger.i('addOrIncrementByBarcode: processing barcode for user $userId');
    final trimmedBarcode = barcode.trim();
    if (trimmedBarcode.isEmpty) {
      throw ArgumentError('Barcode cannot be empty');
    }

    final normalizedBarcode = _normalizeBarcode(trimmedBarcode);

    final products = await _productRepository.getProducts(userId);
    Product? existingProduct;
    for (final product in products) {
      if (product.barcode == normalizedBarcode || product.barcode == barcode) {
        existingProduct = product;
        break;
      }
    }

    if (existingProduct != null) {
      _logger.i('Barcode matched existing product: ${existingProduct.name}');

      // Calculate smart default expiry if none exists, else just increment quantity
      final estimatedExpiry = _shelfLifeService.estimateExpiration(
        existingProduct,
      );
      final newExpiries = List<ExpiryEntry>.from(existingProduct.expiries);

      if (estimatedExpiry != null) {
        newExpiries.add(
          ExpiryEntry(quantity: 1, expirationDate: estimatedExpiry),
        );
      }

      final updatedProduct = existingProduct.copyWith(
        expiries: newExpiries,
        nonExpiringQuantity: estimatedExpiry == null
            ? existingProduct.nonExpiringQuantity + 1
            : existingProduct.nonExpiringQuantity,
      );
      _validateOrThrow(updatedProduct);
      await _productRepository.update(updatedProduct);
      _invalidateCache();
      return ScanAddProductResult(
        product: updatedProduct,
        matchedExisting: true,
        estimatedExpiryDays: estimatedExpiry?.difference(DateTime.now()).inDays,
      );
    }

    final lookup = await _offClient.lookup(
      normalizedBarcode,
      languageCode: languageCode,
    );
    switch (lookup) {
      case OffFound(product: final data):
        final estimatedExpiry = _estimateFromTags(data.tags);
        final newProduct = Product(
          id: '',
          name: data.name ?? normalizedBarcode,
          description: '',
          userId: userId,
          nonExpiringQuantity: estimatedExpiry == null ? 1 : 0,
          barcode: normalizedBarcode,
          imageUrl: data.imageUrl,
          tags: data.tags,
          expiries: estimatedExpiry != null
              ? [ExpiryEntry(quantity: 1, expirationDate: estimatedExpiry)]
              : [],
        );

        _validateOrThrow(newProduct);
        final addedProduct = await _productRepository.add(newProduct);
        _invalidateCache();
        _logger.i('Created new product from OFF API: $normalizedBarcode');
        return ScanAddProductResult(
          product: addedProduct,
          matchedExisting: false,
          estimatedExpiryDays: estimatedExpiry
              ?.difference(DateTime.now())
              .inDays,
        );
      case OffOffline():
        // Save the barcode now and look it up once the connection returns.
        final placeholder = Product(
          id: '',
          name: normalizedBarcode,
          description: '',
          userId: userId,
          nonExpiringQuantity: 1,
          barcode: normalizedBarcode,
        );
        _validateOrThrow(placeholder);
        final saved = await _productRepository.add(placeholder);
        _invalidateCache();
        await _lookupQueue.enqueue(
          QueuedBarcodeLookup(
            productId: saved.id,
            barcode: normalizedBarcode,
            languageCode: languageCode,
          ),
        );
        _logger.i('Offline: queued lookup for barcode $normalizedBarcode');
        return ScanAddProductResult(
          product: saved,
          matchedExisting: false,
          offline: true,
        );
      case OffNotFound():
        // Return an unsaved draft to prefill the manual-entry form; its empty
        // id is assigned by the repository on save.
        _logger.i('Barcode not found on OFF API: $normalizedBarcode');
        return ScanAddProductResult(
          product: Product(
            id: '',
            name: '',
            description: '',
            userId: userId,
            nonExpiringQuantity: 1,
            barcode: normalizedBarcode,
          ),
          matchedExisting: false,
          notFound: true,
        );
    }
  }

  DateTime? _estimateFromTags(List<String> tags) =>
      _shelfLifeService.estimateExpiration(
        // A temporary, minimal product instance for estimation.
        Product(id: '0', name: '', description: '', userId: '', tags: tags),
      );

  Future<int>? _replay;

  /// Looks up barcodes queued while offline and fills in their placeholder
  /// products. Stops at the first lookup that is still offline; returns the
  /// number of products updated. Concurrent calls share one run.
  Future<int> replayQueuedLookups() =>
      _replay ??= _replayQueuedLookups().whenComplete(() => _replay = null);

  Future<int> _replayQueuedLookups() async {
    var resolved = 0;
    for (final entry in _lookupQueue.entries) {
      final lookup = await _offClient.lookup(
        entry.barcode,
        languageCode: entry.languageCode,
      );
      if (lookup is OffOffline) break;
      if (lookup case OffFound(product: final data)) {
        try {
          final current = await _productRepository.get(entry.productId);
          // Skip a placeholder that was deleted or edited in the meantime.
          if (current != null && current.name == entry.barcode) {
            final updated = current.copyWith(
              name: data.name ?? current.name,
              imageUrl: data.imageUrl ?? current.imageUrl,
              tags: {...current.tags, ...data.tags}.toList(),
            );
            _validateOrThrow(updated);
            await _productRepository.update(updated);
            _invalidateCache();
            resolved++;
          }
        } catch (error, stack) {
          _logger.w(
            'Failed to update queued product ${entry.productId}',
            error: error,
            stackTrace: stack,
          );
        }
      }
      await _lookupQueue.remove(entry);
    }
    if (resolved > 0) _logger.i('Resolved $resolved queued barcode lookups.');
    return resolved;
  }

  /// Fetches all products for a specific user
  /// Returns empty list if userId is null (no user logged in)
  Future<List<Product>> getProducts(
    String? userId, {
    bool forceRefresh = false,
  }) async {
    if (userId == null) {
      _logger.w('No user logged in, returning empty product list.');
      return [];
    }

    final cached = _productsCache[userId];
    if (!forceRefresh && cached != null) {
      final (fetchedAt, products) = cached;
      if (DateTime.now().difference(fetchedAt) < _cacheTtl) {
        _logger.i('Returning cached products for user: $userId');
        return List.of(products);
      }
      _productsCache.remove(userId);
    }
    if (!forceRefresh) {
      // Concurrent callers (the dashboard loads its expired and expiring-soon
      // lists together) share one repository query.
      final pending = _pendingFetches[userId];
      if (pending != null) {
        _logger.i('Joining in-flight product fetch for user: $userId');
        return List.of(await pending);
      }
    }
    final fetch = _fetchProducts(userId);
    _pendingFetches[userId] = fetch;
    try {
      return List.of(await fetch);
    } finally {
      if (identical(_pendingFetches[userId], fetch)) {
        _pendingFetches.remove(userId);
      }
    }
  }

  Future<List<Product>> _fetchProducts(String userId) async {
    final sequence = (_fetchSequence[userId] ?? 0) + 1;
    _fetchSequence[userId] = sequence;
    _logger.i('Fetching products for user: $userId');
    final generation = _cacheGeneration;
    try {
      var products = await _productRepository.getProducts(userId);
      if (generation != _cacheGeneration) {
        _logger.i('Cache invalidated during fetch, retrying for user: $userId');
        products = await _productRepository.getProducts(userId);
      }
      if (sequence == _fetchSequence[userId]) {
        _productsCache[userId] = (DateTime.now(), List.of(products));
      }
      _logger.i('Successfully fetched ${products.length} products for user.');
      return products;
    } catch (e) {
      _logger.e('Error fetching user products: $e');
      rethrow;
    }
  }

  /// Fetches personal registry products for a specific user.
  Future<List<Product>> getPersonalProducts(String? userId) async {
    if (userId == null) {
      _logger.w('No user logged in, returning empty personal product list.');
      return [];
    }

    _logger.i('Fetching personal registry products for user: $userId');
    try {
      final products = await _productRepository.getPersonalProducts(userId);
      _logger.i(
        'Successfully fetched ${products.length} personal registry products for user.',
      );
      return products;
    } catch (e) {
      _logger.e('Error fetching personal registry products: $e');
      rethrow;
    }
  }

  /// Returns products for [userId] that expire today or within
  /// [expiringSoonDays] days.
  Future<List<Product>> getExpiringSoon(
    String? userId, {
    int expiringSoonDays = PreferencesConfig.defaultExpiringSoonDays,
  }) async {
    final products = await getProducts(userId);
    final upcoming = [
      for (final product in products)
        if (product.daysUntilFirstExpiry(expired: false) case final int days
            when days == 0 || days <= expiringSoonDays)
          (product: product, days: days),
    ]..sort((a, b) => a.days.compareTo(b.days));
    return [for (final entry in upcoming) entry.product];
  }

  /// Returns products for [userId] with at least one expired quantity, oldest
  /// expiry first.
  Future<List<Product>> getExpired(String? userId) async {
    final products = await getProducts(userId);
    final expired = [
      for (final product in products)
        if (product.daysUntilFirstExpiry(expired: true) case final int days)
          (product: product, days: days),
    ]..sort((a, b) => a.days.compareTo(b.days));
    return [for (final entry in expired) entry.product];
  }

  /// Fetches all global products (catalog)
  Future<List<Product>> getAllProducts() async {
    _logger.i('Fetching all global products.');
    try {
      final products = await _productRepository.getGlobalProducts();
      _logger.i('Successfully fetched ${products.length} global products.');
      return products;
    } catch (e) {
      _logger.e('Error fetching global products: $e');
      rethrow;
    }
  }

  Future<Product?> getProductById(String id) async {
    _logger.i('Fetching product by ID: $id');
    try {
      return await _productRepository.get(id);
    } catch (e) {
      _logger.e('Error fetching product: $e');
      rethrow;
    }
  }

  void _validateOrThrow(Product product) {
    final validationResult = _productValidator.validate(product);
    if (!validationResult.isValid) {
      _logger.e('Validation failed for product: ${product.name}');
      throw ValidationException(validationResult.errors.first);
    }
  }

  /// Saves a new product. An empty [Product.id] is replaced by the repository.
  Future<Product> addProduct(Product product) async {
    _logger.i('Adding product: ${product.name}');
    _validateOrThrow(product);
    try {
      final addedProduct = await _productRepository.add(product);
      _invalidateCache();
      _logger.i('Successfully added product: ${product.name}');
      return addedProduct;
    } catch (e) {
      _logger.e('Error adding product: $e');
      rethrow;
    }
  }

  /// Saves [draft] as a new current product and returns it with its generated
  /// id. With [withPersonalTemplate], a personal registry template is saved
  /// first and the new product is mapped to it. Everything is validated before
  /// the first write.
  Future<Product> createProduct(
    Product draft, {
    bool withPersonalTemplate = false,
  }) async {
    final current = draft.copyWith(
      id: '',
      isGlobal: false,
      registryType: 'current',
    );
    if (!withPersonalTemplate) return addProduct(current);

    final template = draft.copyWith(
      id: '',
      isGlobal: false,
      registryType: 'personal',
      mappedFromProductId: null,
      expiries: const [],
      nonExpiringQuantity: 0,
    );
    _validateOrThrow(template);
    _validateOrThrow(current);
    final savedTemplate = await addProduct(template);
    return addProduct(current.copyWith(mappedFromProductId: savedTemplate.id));
  }

  Future<void> updateProduct(Product product) async {
    _logger.i('Updating product: ${product.name}');
    _validateOrThrow(product);
    try {
      await _productRepository.update(product);
      _invalidateCache();
      _logger.i('Successfully updated product: ${product.name}');
    } catch (e) {
      _logger.e('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    _logger.i('Deleting product: $id');
    try {
      await _productRepository.delete(id);
      _invalidateCache();
      _logger.i('Successfully deleted product: $id');
    } catch (e) {
      _logger.e('Error deleting product: $e');
      rethrow;
    }
  }

  Future<void> deleteCollection(
    Collection source, {
    String? destinationId,
  }) async {
    try {
      await _productRepository.deleteCollection(
        source,
        destinationId: destinationId,
      );
      _invalidateCache();
    } catch (e) {
      _logger.e('Error deleting collection: ${e.runtimeType}');
      rethrow;
    }
  }
}

class ScanAddProductResult {
  final Product product;
  final bool matchedExisting;
  final bool notFound;

  /// Open Food Facts was unreachable: the barcode was saved as a placeholder
  /// product and its lookup is queued until the connection returns.
  final bool offline;
  final int? estimatedExpiryDays;

  const ScanAddProductResult({
    required this.product,
    required this.matchedExisting,
    this.notFound = false,
    this.offline = false,
    this.estimatedExpiryDays,
  });
}
