import '../models/collection_model.dart';
import 'repository_interface.dart';

/// Abstract interface for collection data access operations.
/// Implementations can be in-memory, Firestore, or any other data source.
/// Extends the generic IRepository interface with collection-specific methods.
abstract class ICollectionRepository extends IRepository<Collection, String> {
  @override
  Future<Collection> add(Collection collection);
  
  @override
  Future<Collection?> get(String id);
  
  @override
  Future<void> update(Collection collection);
  
  @override
  Future<void> delete(String id);
  
  @override
  Future<List<Collection>> getAll();
  
  // Collection-specific methods
  Future<List<Collection>> getUserCollections(String userId);
  Future<void> addProductToCollection(String collectionId, int productId);
  Future<void> removeProductFromCollection(String collectionId, int productId);
  
  // Legacy method names for compatibility
  Future<Collection> addCollection(Collection collection) => add(collection);
  Future<Collection?> getCollection(String id) => get(id);
  Future<void> updateCollection(Collection collection) => update(collection);
  Future<void> deleteCollection(String id) => delete(id);
  Future<List<Collection>> getAllCollections() => getAll();
}
