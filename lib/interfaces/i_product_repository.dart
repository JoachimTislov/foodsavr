import '../models/collection_model.dart';
import '../models/product_model.dart';
import 'i_repository.dart';

/// Abstract interface for product data access operations.
/// Implementations can be in-memory, Firestore, or any other data source.
/// Extends the generic IRepository interface with product-specific methods.
abstract class IProductRepository extends IRepository<Product, String> {
  /// Atomically move collection members or delete them, then delete the source.
  Future<void> deleteCollection(Collection source, {String? destinationId});

  Future<List<Product>> getProducts(
    String userId,
  ); // Get user-specific products
  Future<List<Product>> getPersonalProducts(
    String userId,
  ); // Get user-specific personal registry products
  Future<List<Product>> getGlobalProducts(); // Get global catalog products
}
