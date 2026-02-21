import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import '../mock_data/collections.dart';
import '../utils/config.dart';
import '../interfaces/i_auth_service.dart';
import '../interfaces/i_collection_repository.dart';
import '../interfaces/i_product_repository.dart';
import '../mock_data/global_products.dart';
import '../mock_data/inventory_products.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../utils/collection_types.dart';

class SeedingService {
  final IAuthService _authService;
  final IProductRepository _productRepository;
  final ICollectionRepository _collectionRepository;
  final Logger _logger;

  SeedingService(
    this._authService,
    this._productRepository,
    this._collectionRepository,
    this._logger,
  );

  Future<void> seedDatabase() async {
    final userId = await _seedUser();
    final addedProducts = await _seedProducts(userId);
    await _seedCollections(userId, addedProducts);
    await _seedGlobalProducts();
  }

  Future<String> _seedUser() async {
    User? user;
    try {
      final credential = await _authService.signUp(
        email: Config.testUserEmail,
        password: Config.testUserPassword,
      );
      user = credential.user;
    } catch (_) {
      // ignore error ...
    }
    if (user == null) {
      _logger.e(
        'SeedingService: signUp returned a null user for '
        '${Config.testUserEmail}',
      );
      throw StateError('Failed to seed database: test user was not created.');
    }
    return user.uid;
  }

  Future<List<Product>> _seedProducts(String userId) async {
    final now = DateTime.now();
    final productsData = InventoryProductsData.getProducts();
    final addedProducts = <Product>[];

    for (var data in productsData) {
      final expirationDays = data['expirationDays'] as int?;
      final quantity = data['quantity'] as int? ?? 1;

      final product = Product(
        id: data['id'] as int,
        name: data['name'] as String,
        description: data['description'] as String,
        userId: userId,
        expiries: expirationDays != null
            ? [
                ExpiryEntry(
                  quantity: quantity,
                  expirationDate: now.add(Duration(days: expirationDays)),
                ),
              ]
            : [],
        nonExpiringQuantity: expirationDays == null ? quantity : 0,
        category: data['category'] as String?,
      );
      await _productRepository.add(product);
      addedProducts.add(product);
    }

    return addedProducts;
  }

  Future<void> _seedGlobalProducts() async {
    final productsData = GlobalProductsData.getProducts();

    for (var data in productsData) {
      final product = Product(
        id: data['id'] as int,
        name: data['name'] as String,
        description: data['description'] as String,
        userId: 'global',
        expiries: [],
        category: data['category'] as String?,
        isGlobal: true,
      );
      await _productRepository.add(product);
    }
  }

  Future<void> _seedCollections(
    String userId,
    List<Product> addedProducts,
  ) async {
    if (addedProducts.isEmpty) return;

    final collectionsData = CollectionsData.getCollections();
    final totalProducts = addedProducts.length;

    for (var data in collectionsData) {
      // Map productIds from mock data to actual product IDs safely
      final mockProductIds = List<int>.from(data['productIds'] as List);
      final actualProductIds = <int>[];

      for (var mockId in mockProductIds) {
        // Calculate safe index based on mock ID and available products
        final index = (mockId - 1) % totalProducts;
        if (index >= 0 && index < totalProducts) {
          actualProductIds.add(addedProducts[index].id);
        }
      }

      final collection = Collection(
        id: data['id'] as String,
        name: data['name'] as String,
        productIds: actualProductIds,
        userId: userId,
        description: data['description'] as String?,
        type: _parseCollectionType(data['type'] as String),
      );
      await _collectionRepository.add(collection);
    }
  }

  CollectionType _parseCollectionType(String typeString) {
    switch (typeString) {
      case 'inventory':
        return CollectionType.inventory;
      case 'shoppingList':
        return CollectionType.shoppingList;
      default:
        return CollectionType.inventory;
    }
  }
}
