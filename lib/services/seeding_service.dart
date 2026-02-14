import '../interfaces/auth_service.dart';
import '../interfaces/product_repository.dart';
import '../interfaces/collection_repository.dart';
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
    await _seedProducts(userId);
    await _seedCollections(userId);
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

  Future<void> _seedProducts(String userId) async {
    final now = DateTime.now();
    final productsData = InventoryProductsData.getProducts();

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
    }
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

  Future<void> _seedCollections(String userId) async {
    final collectionsData = CollectionsData.getCollections();

    for (var data in collectionsData) {
      final collection = Collection(
        id: data['id'] as String,
        name: data['name'] as String,
        productIds: List<int>.from(data['productIds'] as List),
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
      case 'favorites':
        return CollectionType.favorites;
      case 'custom':
        return CollectionType.custom;
      default:
        return CollectionType.custom;
    }
  }
}
