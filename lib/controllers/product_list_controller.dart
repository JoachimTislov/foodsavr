import 'package:flutter/foundation.dart';

import '../interfaces/i_auth_service.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../utils/collection_types.dart';
import '../utils/view_mode_helper.dart';

/// Manages the product list state for a product list view, keeping the view
/// free of service logic and manual setState calls.
///
/// Refreshes fetch products and the user's collections concurrently and
/// publish a single state change once both complete, so a refresh triggers
/// one rebuild of the watching widgets instead of several sequential ones.
class ProductListController extends ChangeNotifier {
  final ProductService _productService;
  final CollectionService _collectionService;
  final IAuthService _authService;
  final bool _showGlobalProducts;

  ProductListController({
    required ProductService productService,
    required CollectionService collectionService,
    required IAuthService authService,
    bool showGlobalProducts = false,
  }) : _productService = productService,
       _collectionService = collectionService,
       _authService = authService,
       _showGlobalProducts = showGlobalProducts;

  List<Product> _products = const [];
  Map<String, List<String>> _productInventories = const {};
  ProductViewMode _viewMode = ProductViewMode.normal;

  /// Set when fetching inventory names failed during the last [load];
  /// the product list itself is still published.
  Object? inventoryLoadError;

  List<Product> get products => _products;
  Map<String, List<String>> get productInventories => _productInventories;
  ProductViewMode get viewMode => _viewMode;

  /// The signed-in user at the start of the last [load]; null when signed out
  /// (or when showing global products, which are not user-scoped).
  String? get userId => _showGlobalProducts
      ? null
      : _authService.getUserId();

  /// Applies the view mode and notifies only when it changed.
  void setViewMode(ProductViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
  }

  /// Loads products (and the inventory map for the details view mode)
  /// for the current user and notifies listeners once both complete.
  /// Completes normally when there is no signed-in user (state is cleared).
  Future<void> load({bool forceRefresh = false}) async {
    final userId = _showGlobalProducts ? null : _authService.getUserId();
    if (!_showGlobalProducts && userId == null) {
      _products = const [];
      _productInventories = const {};
      inventoryLoadError = null;
      notifyListeners();
      return;
    }

    final productsFuture = _showGlobalProducts
        ? _productService.getAllProducts()
        : _productService.getProducts(userId, forceRefresh: forceRefresh);

    Object? inventoryError;
    final collectionsFuture = _showGlobalProducts || userId == null
        ? Future.value(const <Collection>[])
        : _collectionService.getCollectionsForUser(userId).catchError((
          Object e,
        ) {
          inventoryError = e;
          return const <Collection>[];
        });

    final results = await Future.wait([productsFuture, collectionsFuture]);
    final products = results[0] as List<Product>;
    final collections = results[1] as List<Collection>;

    _products = products;
    inventoryLoadError = inventoryError;
    if (inventoryError == null) {
      final productIds = products.map((p) => p.id).toSet();
      final inventoryMap = <String, List<String>>{};
      for (final collection in collections) {
        if (collection.type != CollectionType.inventory) continue;
        for (final pid in collection.productIds) {
          if (productIds.contains(pid)) {
            inventoryMap.putIfAbsent(pid, () => []).add(collection.name);
          }
        }
      }
      _productInventories = inventoryMap;
    } else {
      _productInventories = const {};
    }
    notifyListeners();
  }
}
