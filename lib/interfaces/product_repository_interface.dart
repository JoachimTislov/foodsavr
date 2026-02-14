import '../models/product_model.dart';
import 'repository_interface.dart';

/// Abstract interface for product data access operations.
/// Implementations can be in-memory, Firestore, or any other data source.
/// Extends the generic IRepository interface with product-specific methods.
abstract class IProductRepository extends IRepository<Product, int> {
  @override
  Future<Product> add(Product product);
  
  @override
  Future<Product?> get(int id);
  
  @override
  Future<void> update(Product product);
  
  @override
  Future<void> delete(int id);
  
  @override
  Future<List<Product>> getAll(); // Get all products (for admin)
  
  // Product-specific methods
  Future<List<Product>> getProducts(String userId); // Get user-specific products
  Future<List<Product>> getGlobalProducts(); // Get global catalog products
  
  // Legacy method names for compatibility
  Future<Product> addProduct(Product product) => add(product);
  Future<Product?> getProduct(int id) => get(id);
  Future<void> updateProduct(Product product) => update(product);
  Future<void> deleteProduct(int id) => delete(id);
  Future<List<Product>> getAllProducts() => getAll();
}
