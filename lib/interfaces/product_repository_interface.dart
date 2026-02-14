import '../models/product_model.dart';

/// Abstract interface for product data access operations.
/// Implementations can be in-memory, Firestore, or any other data source.
abstract class IProductRepository {
  Future<Product> addProduct(Product product);
  Future<Product?> getProduct(int id);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(int id);
  Future<List<Product>> getAllProducts(); // Get all products (for admin)
  Future<List<Product>> getProducts(String userId); // Get user-specific products
  Future<List<Product>> getGlobalProducts(); // Get global catalog products
}
