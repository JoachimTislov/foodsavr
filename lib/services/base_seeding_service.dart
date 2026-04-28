import '../mock_data/collections.dart';
import '../mock_data/global_products.dart';
import '../mock_data/inventory_products.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../utils/collection_types.dart';

abstract class BaseSeedingService {
  /// Abstract methods to be implemented by platform-specific services
  Future<String> createTestUser(String email, String password);
  Future<void> addProduct(Product product);
  Future<void> addCollection(Collection collection);

  /// Seeds the database with the provided user credentials.
  /// Returns the created user ID.
  Future<String> seedAllData(String email, String password) async {
    final userId = await createTestUser(email, password);
    final addedProducts = await seedInventoryProducts(userId);
    await seedCollections(userId, addedProducts);
    await seedGlobalProducts();
    return userId;
  }

  /// Seeds inventory products for a specific user.
  Future<List<Product>> seedInventoryProducts(String userId) async {
    final productsData = InventoryProductsData.getProducts();
    final addedProducts = <Product>[];
    final now = DateTime.now();

    for (var data in productsData) {
      final id = data['id'] as int;
      final expirationDays = data['expirationDays'] as int?;
      final quantity = data['quantity'] as int? ?? 1;

      final product = Product(
        id: id,
        name: data['name'] as String,
        description: data['description'] as String,
        userId: userId,
        nonExpiringQuantity: expirationDays == null ? quantity : 0,
        expiries: expirationDays != null
            ? [
                ExpiryEntry(
                  quantity: quantity,
                  expirationDate: now.add(Duration(days: expirationDays)),
                ),
              ]
            : [],
        category: data['category'] as String?,
      );

      await addProduct(product);
      addedProducts.add(product);
    }

    return addedProducts;
  }

  /// Seeds global products catalog.
  Future<void> seedGlobalProducts() async {
    final productsData = GlobalProductsData.getProducts();

    for (var data in productsData) {
      final product = Product(
        id: data['id'] as int,
        name: data['name'] as String,
        description: data['description'] as String,
        userId: 'global',
        isGlobal: true,
        category: data['category'] as String?,
        expiries: [],
        registryType: 'global',
      );

      await addProduct(product);
    }
  }

  /// Seeds collections for a specific user.
  Future<void> seedCollections(
    String userId,
    List<Product> addedProducts,
  ) async {
    if (addedProducts.isEmpty) return;

    final collectionsData = CollectionsData.getCollections();
    final totalProducts = addedProducts.length;

    for (var data in collectionsData) {
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

      await addCollection(collection);
    }
  }

  CollectionType _parseCollectionType(String typeString) {
    for (var type in CollectionType.values) {
      if (type.name == typeString) {
        return type;
      }
    }
    // Fallback to older switch logic for compatibility
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
