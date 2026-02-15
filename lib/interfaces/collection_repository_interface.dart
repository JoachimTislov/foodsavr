import '../models/collection_model.dart';
import 'repository_interface.dart';

/// Abstract interface for collection data access operations.
/// Implementations can be in-memory, Firestore, or any other data source.
/// Extends the generic IRepository interface with collection-specific methods.
abstract class ICollectionRepository extends IRepository<Collection, String> {
  Future<List<Collection>> getCollections(String userId);
  Future<void> addProduct(String collectionId, int productId);
  Future<void> removeProduct(String collectionId, int productId);
}
