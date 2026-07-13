import '../models/m_collection.dart';
import 'ir.dart';

/// Abstract interface for collection data access operations.
/// Implementations can be in-memory, Firestore, or any other data source.
/// Extends the generic IRepository interface with collection-specific methods.
abstract class ICollectionRepository extends IRepository<Collection, String> {
  Future<List<Collection>> getCollections(String userId);
  Future<void> addProduct(String collectionId, String productId);
  Future<void> addProducts(String collectionId, List<String> productIds);
  Future<void> removeProduct(String collectionId, String productId);
}
