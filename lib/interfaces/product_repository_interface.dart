import '../models/product_model.dart';
import 'repository_interface.dart';

/// Abstract interface for product data access operations.
/// Implementations can be in-memory, Firestore, or any other data source.
/// Extends the generic IRepository interface with product-specific methods.
abstract class IProductRepository extends IRepository<Product, int> {
  Future<List<Product>> getProducts(
    String userId,
  ); // Get user-specific products
  Future<List<Product>> getGlobalProducts(); // Get global catalog products
}
