import '../interfaces/auth_service_interface.dart';
import '../interfaces/product_repository_interface.dart';
import '../interfaces/collection_repository_interface.dart';
import '../models/product_model.dart';
import '../models/collection_model.dart';
import '../utils/environment_config.dart';
import '../mock_data/inventory_products.dart';
import '../mock_data/global_products.dart';
import '../mock_data/collections.dart';

class SeedingService {
  final IAuthService _authService;
  final IProductRepository _productRepository;
  final ICollectionRepository _collectionRepository;

  SeedingService(
    this._authService,
    this._productRepository,
    this._collectionRepository,
  );

  Future<void> seedDatabase() async {
    final userId = await _seedUsers();
    final addedProducts = await _seedProducts(userId);
    await _seedCollections(userId, addedProducts);
    await _seedGlobalProducts();
  }

  Future<String> _seedUsers() async {
    try {
      final userCred = await _authService.authenticate(
        isLogin: false,
        email: EnvironmentConfig.testUserEmail,
        password: EnvironmentConfig.testUserPassword,
      );
      return userCred?.user?.uid ?? 'test-user-id';
    } catch (e) {
      // User might already exist, try to login
      try {
        final userCred = await _authService.authenticate(
          isLogin: true,
          email: EnvironmentConfig.testUserEmail,
          password: EnvironmentConfig.testUserPassword,
        );
        return userCred?.user?.uid ?? 'test-user-id';
      } catch (e) {
        return 'test-user-id';
      }
    }
  }

  Future<List<Product>> _seedProducts(String userId) async {
    final now = DateTime.now();
    final productsData = InventoryProductsData.getProducts();
    final addedProducts = <Product>[];

    for (var data in productsData) {
      final product = Product(
        id: data['id'] as int,
        name: data['name'] as String,
        description: data['description'] as String,
        userId: userId,
        expirationDate: data['expirationDays'] != null
            ? now.add(Duration(days: data['expirationDays'] as int))
            : null,
        quantity: data['quantity'] as int,
        category: data['category'] as String?,
      );
      await _productRepository.addProduct(product);
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
        category: data['category'] as String?,
        isGlobal: true,
      );
      await _productRepository.addProduct(product);
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
      await _collectionRepository.addCollection(collection);
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
