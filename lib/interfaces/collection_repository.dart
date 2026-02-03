import '../models/collection_model.dart';

/// Abstract interface for collection data access operations.
/// Implementations can be in-memory, Firestore, or any other data source.
abstract class ICollectionRepository {
  Future<Collection> addCollection(Collection collection);
  Future<Collection?> getCollection(String id);
  Future<void> updateCollection(Collection collection);
  Future<void> deleteCollection(String id);
  Future<List<Collection>> getAllCollections();
}
