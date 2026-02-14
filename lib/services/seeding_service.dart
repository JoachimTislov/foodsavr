import '../interfaces/auth_service.dart';
import '../interfaces/product_repository.dart';
import '../interfaces/collection_repository.dart';
import '../models/product_model.dart';
import '../models/collection_model.dart';
import '../utils/environment_config.dart';

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

    // Seed collections
    await _collectionRepository.addCollection(
      Collection(
        id: '1',
        name: 'My Inventory',
        productIds: [addedProducts[0].id, addedProducts[1].id, addedProducts[2].id],
        userId: userId,
        description: 'My personal food inventory',
        type: CollectionType.inventory,
      ),
    );

    await _collectionRepository.addCollection(
      Collection(
        id: '2',
        name: 'Shopping List',
        productIds: [addedProducts[3].id, addedProducts[4].id],
        userId: userId,
        description: 'Items to buy',
        type: CollectionType.shoppingList,
      ),
    );

    await _collectionRepository.addCollection(
      Collection(
        id: '3',
        name: 'Favorites',
        productIds: [addedProducts[5].id, addedProducts[6].id],
        userId: userId,
        description: 'My favorite items',
        type: CollectionType.favorites,
      ),
    );

    // Seed global products
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
    final products = [
      Product(
        id: 1,
        name: 'Apple',
        description: 'A crisp and juicy apple.',
        userId: userId,
        expirationDate: now.add(const Duration(days: 5)),
        quantity: 6,
        category: 'Fruits',
      ),
      Product(
        id: 2,
        name: 'Banana',
        description: 'A ripe and sweet banana.',
        userId: userId,
        expirationDate: now.add(const Duration(days: 2)),
        quantity: 4,
        category: 'Fruits',
      ),
      Product(
        id: 3,
        name: 'Carrot',
        description: 'An orange carrot.',
        userId: userId,
        expirationDate: now.add(const Duration(days: 10)),
        quantity: 8,
        category: 'Vegetables',
      ),
      Product(
        id: 4,
        name: 'Milk',
        description: 'Organic whole milk',
        userId: userId,
        expirationDate: now.add(const Duration(days: 1)),
        quantity: 1,
        category: 'Dairy',
      ),
      Product(
        id: 5,
        name: 'Bread',
        description: 'Whole wheat bread',
        userId: userId,
        expirationDate: now.add(const Duration(days: 3)),
        quantity: 1,
        category: 'Bakery',
      ),
      Product(
        id: 6,
        name: 'Eggs',
        description: 'Farm fresh eggs',
        userId: userId,
        expirationDate: now.add(const Duration(days: 14)),
        quantity: 12,
        category: 'Dairy',
      ),
      Product(
        id: 7,
        name: 'Cheese',
        description: 'Aged cheddar cheese',
        userId: userId,
        expirationDate: now.add(const Duration(days: 20)),
        quantity: 1,
        category: 'Dairy',
      ),
      Product(
        id: 8,
        name: 'Tomato',
        description: 'Fresh red tomatoes',
        userId: userId,
        expirationDate: now.add(const Duration(days: 4)),
        quantity: 5,
        category: 'Vegetables',
      ),
    ];

    final addedProducts = <Product>[];
    for (var product in products) {
      addedProducts.add(await _productRepository.addProduct(product));
    }
    return addedProducts;
  }

  Future<void> _seedGlobalProducts() async {
    final globalProducts = [
      Product(
        id: 1001,
        name: 'Pasta',
        description: 'Italian spaghetti pasta',
        userId: 'global',
        category: 'Pantry',
        isGlobal: true,
      ),
      Product(
        id: 1002,
        name: 'Rice',
        description: 'Long grain white rice',
        userId: 'global',
        category: 'Pantry',
        isGlobal: true,
      ),
      Product(
        id: 1003,
        name: 'Olive Oil',
        description: 'Extra virgin olive oil',
        userId: 'global',
        category: 'Pantry',
        isGlobal: true,
      ),
    ];

    for (var product in globalProducts) {
      await _productRepository.addProduct(product);
    }
  }
}
