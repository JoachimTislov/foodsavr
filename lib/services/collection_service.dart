import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import '../models/collection_model.dart';
import '../interfaces/i_collection_repository.dart';
import '../utils/collection_types.dart';

@lazySingleton
class CollectionService {
  final ICollectionRepository _collectionRepository;
  final Logger _logger;

  CollectionService(this._collectionRepository, this._logger);

  String _redactUserId(String userId) => userId.length <= 6
      ? '***'
      : '${userId.substring(0, 3)}***${userId.substring(userId.length - 3)}';

  /// Get all collections (global for all users)
  Future<List<Collection>> getCollections() async {
    _logger.i('Fetching all collections.');
    try {
      final collections = await _collectionRepository.getAll();
      _logger.i('Successfully fetched ${collections.length} collections.');
      return collections;
    } catch (e) {
      _logger.e('Error fetching collections: $e');
      rethrow;
    }
  }

  /// Get all collections for a specific user
  Future<List<Collection>> getCollectionsForUser(
    String? userId, {
    CollectionType? type,
  }) async {
    if (userId == null) {
      _logger.w('No user logged in, returning empty collection list.');
      return [];
    }
    _logger.i(
      'Fetching collections for user: ${_redactUserId(userId)} with type: $type',
    );
    try {
      List<Collection> collections = await _collectionRepository.getCollections(
        userId,
      );
      if (type != null) {
        collections = collections.where((c) => c.type == type).toList();
      }
      _logger.i(
        'Successfully fetched ${collections.length} collections for user.',
      );
      return collections;
    } catch (e) {
      _logger.e('Error fetching user collections: $e');
      rethrow;
    }
  }

  /// Build a map of product ID → inventory names for the given product IDs
  Future<Map<String, List<String>>> getInventoryNamesForProducts(
    String userId,
    Set<String> productIds,
  ) async {
    _logger.i('Building inventory map for ${productIds.length} products');
    try {
      final collections = await getCollectionsForUser(userId);
      final inventoryMap = <String, List<String>>{};
      for (final collection in collections) {
        if (collection.type == CollectionType.inventory) {
          for (final pid in collection.productIds) {
            if (productIds.contains(pid)) {
              inventoryMap.putIfAbsent(pid, () => []).add(collection.name);
            }
          }
        }
      }
      return inventoryMap;
    } catch (e) {
      _logger.e('Error building inventory map: $e');
      rethrow;
    }
  }

  /// Find all inventories (CollectionType.inventory) that contain a specific product ID
  Future<List<Collection>> getInventoriesByProductId(
    String userId,
    String productId,
  ) async {
    _logger.i(
      'Finding inventories for product $productId and user ${_redactUserId(userId)}',
    );
    try {
      final collections = await getCollectionsForUser(userId);
      final inventories = collections
          .where(
            (c) =>
                c.type == CollectionType.inventory &&
                c.productIds.contains(productId),
          )
          .toList();
      _logger.i(
        'Found ${inventories.length} inventories for product $productId',
      );
      return inventories;
    } catch (e) {
      _logger.e('Error finding inventories for product: $e');
      rethrow;
    }
  }

  /// Get a specific collection by ID
  Future<Collection?> getCollection(String id) async {
    _logger.i('Fetching collection: $id');
    try {
      final collection = await _collectionRepository.get(id);
      if (collection != null) {
        _logger.i('Successfully fetched collection: ${collection.name}');
      }
      return collection;
    } catch (e) {
      _logger.e('Error fetching collection: $e');
      rethrow;
    }
  }

  Future<Collection> addCollection(Collection collection) async {
    _logger.i('Adding collection: ${collection.name}');
    try {
      final added = await _collectionRepository.add(collection);
      _logger.i('Successfully added collection');
      return added;
    } catch (e) {
      _logger.e('Error adding collection: $e');
      rethrow;
    }
  }

  Future<void> updateCollection(Collection collection) async {
    _logger.i('Updating collection: ${collection.name}');
    try {
      await _collectionRepository.update(collection);
      _logger.i('Successfully updated collection');
    } catch (e) {
      _logger.e('Error updating collection: $e');
      rethrow;
    }
  }

  Future<void> deleteCollection(String id) async {
    _logger.i('Deleting collection: $id');
    try {
      await _collectionRepository.delete(id);
      _logger.i('Successfully deleted collection');
    } catch (e) {
      _logger.e('Error deleting collection: $e');
      rethrow;
    }
  }

  /// Create initial collections for a new user idempotently.
  Future<void> createInitialCollections(String userId) async {
    final redactedUserId = _redactUserId(userId);
    _logger.i('Creating initial collections for new user: $redactedUserId');

    try {
      final existingCollections = await getCollectionsForUser(userId);
      final existingTypes = existingCollections.map((c) => c.type).toSet();

      final futures = <Future<void>>[];

      if (!existingTypes.contains(CollectionType.inventory)) {
        _logger.i('Inventory collection not found, creating one.');
        final inventory = Collection(
          id: '', // Let repository generate ID
          name: 'Inventory',
          userId: userId,
          type: CollectionType.inventory,
          productIds: const [],
        );
        futures.add(addCollection(inventory));
      } else {
        _logger.i('Inventory collection already exists, skipping creation.');
      }

      if (!existingTypes.contains(CollectionType.shoppingList)) {
        _logger.i('Shopping list collection not found, creating one.');
        final shoppingList = Collection(
          id: '', // Let repository generate ID
          name: 'Shopping List',
          userId: userId,
          type: CollectionType.shoppingList,
          productIds: const [],
        );
        futures.add(addCollection(shoppingList));
      } else {
        _logger.i('Shopping list collection already exists, skipping creation.');
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
        _logger.i('Successfully created initial collections for new user.');
      } else {
        _logger.i('All initial collections already exist for user.');
      }
    } catch (e, s) {
      _logger.e(
        'Error creating initial collections for user $redactedUserId',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Add a product to a collection (update productIds list)
  Future<void> addProductToCollection(
    String collectionId,
    String productId,
  ) async {
    _logger.i('Adding product $productId to collection $collectionId');
    try {
      await _collectionRepository.addProduct(collectionId, productId);
      _logger.i('Successfully added product to collection');
    } catch (e) {
      _logger.e('Error adding product to collection: $e');
      rethrow;
    }
  }

  /// Add multiple products to a collection in a single atomic operation.
  Future<void> addProductsToCollection(
    String collectionId,
    List<String> productIds,
  ) async {
    _logger.i(
      'Adding ${productIds.length} products to collection $collectionId',
    );
    try {
      await _collectionRepository.addProducts(collectionId, productIds);
      _logger.i('Successfully added products to collection');
    } catch (e) {
      _logger.e('Error adding products to collection: $e');
      rethrow;
    }
  }

  /// Remove a product from a collection (update productIds list)
  Future<void> removeProductFromCollection(
    String collectionId,
    String productId,
  ) async {
    _logger.i('Removing product $productId from collection $collectionId');
    try {
      await _collectionRepository.removeProduct(collectionId, productId);
      _logger.i('Successfully removed product from collection');
    } catch (e) {
      _logger.e('Error removing product from collection: $e');
      rethrow;
    }
  }
}
