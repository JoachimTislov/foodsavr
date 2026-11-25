import '../models/collection_model.dart';
import '../models/product_model.dart';
import 'i_repository.dart';

/// Abstract interface for collection data access operations.
/// Implementations can be in-memory, Firestore, or any other data source.
/// Extends the generic IRepository interface with collection-specific methods.
abstract class ICollectionRepository extends IRepository<Collection, String> {
  Future<List<Collection>> getCollections(
    String userId, {
    bool serverOnly = false,
  });

  /// Metadata-only edits preserve the membership read in the transaction.
  @override
  Future<void> update(Collection collection, {bool metadataOnly = false});

  /// Cached results can be displayed. Only authoritative results permit repair.
  Future<({List<Product> products, bool authoritative})> getMemberProducts(
    String userId,
  );

  /// Confirms missing or inaccessible products directly on the server.
  Future<bool> isProductMissingOrUnreadable(String id);
  Future<void> removeProducts(String collectionId, Iterable<String> productIds);
  Future<void> addProduct(String collectionId, String productId);
  Future<void> addProducts(String collectionId, List<String> productIds);
  Future<void> removeProduct(String collectionId, String productId);
  Future<void> addCollectionsInBatch(List<Collection> collections);
}
