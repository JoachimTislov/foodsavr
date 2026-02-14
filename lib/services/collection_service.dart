import 'package:logger/logger.dart';
import '../models/collection_model.dart';
import '../interfaces/collection_repository_interface.dart';

class CollectionService {
  final ICollectionRepository _collectionRepository;
  final Logger _logger;

  CollectionService(this._collectionRepository, this._logger);

  /// Get all collections (global for all users)
  Future<List<Collection>> getCollections() async {
    _logger.i('Fetching all collections.');
    try {
      final collections = await _collectionRepository.getAllCollections();
      _logger.i('Successfully fetched ${collections.length} collections.');
      return collections;
    } catch (e) {
      _logger.e('Error fetching collections: $e');
      rethrow;
    }
  }

  /// Get a specific collection by ID
  Future<Collection?> getCollection(String id) async {
    _logger.i('Fetching collection: $id');
    try {
      final collection = await _collectionRepository.getCollection(id);
      if (collection != null) {
        _logger.i('Successfully fetched collection: ${collection.name}');
      }
      return collection;
    } catch (e) {
      _logger.e('Error fetching collection: $e');
      rethrow;
    }
  }

  /// Add a product to a collection (update productIds list)
  Future<void> addProductToCollection(String collectionId, int productId) async {
    _logger.i('Adding product $productId to collection $collectionId');
    try {
      final collection = await _collectionRepository.getCollection(collectionId);
      if (collection == null) {
        throw Exception('Collection not found');
      }
      
      if (!collection.productIds.contains(productId)) {
        final updatedProductIds = [...collection.productIds, productId];
        final updatedCollection = Collection(
          id: collection.id,
          name: collection.name,
          productIds: updatedProductIds,
          userId: collection.userId,
          description: collection.description,
          type: collection.type,
        );
        await _collectionRepository.updateCollection(updatedCollection);
        _logger.i('Successfully added product to collection');
      }
    } catch (e) {
      _logger.e('Error adding product to collection: $e');
      rethrow;
    }
  }

  /// Remove a product from a collection (update productIds list)
  Future<void> removeProductFromCollection(String collectionId, int productId) async {
    _logger.i('Removing product $productId from collection $collectionId');
    try {
      final collection = await _collectionRepository.getCollection(collectionId);
      if (collection == null) {
        throw Exception('Collection not found');
      }
      
      final updatedProductIds = collection.productIds.where((id) => id != productId).toList();
      final updatedCollection = Collection(
        id: collection.id,
        name: collection.name,
        productIds: updatedProductIds,
        userId: collection.userId,
        description: collection.description,
        type: collection.type,
      );
      await _collectionRepository.updateCollection(updatedCollection);
      _logger.i('Successfully removed product from collection');
    } catch (e) {
      _logger.e('Error removing product from collection: $e');
      rethrow;
    }
  }
}
