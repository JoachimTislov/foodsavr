import 'package:easy_localization/easy_localization.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:foodsavr/interfaces/i_validator.dart';

import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../interfaces/i_collection_repository.dart';
import '../utils/collection_types.dart';

@lazySingleton
class CollectionService {
  final ICollectionRepository _collectionRepository;
  final IValidator<Collection> _collectionValidator;
  final Logger _logger;

  CollectionService(
    this._collectionRepository,
    this._collectionValidator,
    this._logger,
  );

  String _redactUserId(String userId) => userId.length <= 6
      ? '***'
      : '${userId.substring(0, 3)}***${userId.substring(userId.length - 3)}';

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
    final validationResult = _collectionValidator.validate(collection);
    if (!validationResult.isValid) {
      _logger.e('Validation failed for collection: ${collection.name}');
      throw FormatException(validationResult.errors.first.message);
    }
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
    final validationResult = _collectionValidator.validate(collection);
    if (!validationResult.isValid) {
      _logger.e('Validation failed for collection: ${collection.name}');
      throw FormatException(validationResult.errors.first.message);
    }
    try {
      await _collectionRepository.update(collection);
      _logger.i('Successfully updated collection');
    } catch (e) {
      _logger.e('Error updating collection: $e');
      rethrow;
    }
  }

  /// Resolve the members in collection order and prune legacy dangling IDs.
  Future<(Collection, List<Product>)> loadContents(
    Collection collection,
  ) async {
    if (collection.productIds.isEmpty) return (collection, <Product>[]);
    final members = await _collectionRepository.getMemberProducts(
      collection.userId,
    );
    final byId = {for (final member in members) member.id: member};
    final products = [
      for (final id in collection.productIds.toSet()) ?byId[id],
    ];
    await _collectionRepository.removeProducts(
      collection.id,
      collection.productIds.toSet().difference(byId.keys.toSet()),
    );
    return (
      collection.copyWith(productIds: products.map((p) => p.id).toList()),
      products,
    );
  }

  Future<Map<String, int>> resolveCounts(
    String userId,
    List<Collection> collections,
  ) async {
    if (collections.every((collection) => collection.productIds.isEmpty)) {
      return {for (final collection in collections) collection.id: 0};
    }
    final members = await _collectionRepository.getMemberProducts(userId);
    final ids = members.map((product) => product.id).toSet();
    return {
      for (final collection in collections)
        collection.id: collection.productIds.toSet().intersection(ids).length,
    };
  }

  /// Fill gaps in a user's initial collections without replacing existing types.
  Future<void> createInitialCollections(String userId) async {
    final existing = await _collectionRepository.getCollections(
      userId,
      serverOnly: true,
    );
    final existingTypes = existing.map((collection) => collection.type).toSet();

    // Stable IDs let concurrent sessions converge on one document per type.
    final missing = [
      if (!existingTypes.contains(CollectionType.inventory))
        Collection(
          id: 'initial-inventory-$userId',
          name: 'collection.type_inventory'.tr(),
          userId: userId,
          type: CollectionType.inventory,
          productIds: const [],
        ),
      if (!existingTypes.contains(CollectionType.shoppingList))
        Collection(
          id: 'initial-shopping-list-$userId',
          name: 'collection.defaultShoppingListName'.tr(),
          userId: userId,
          type: CollectionType.shoppingList,
          productIds: const [],
        ),
    ];
    if (missing.isNotEmpty) {
      await _collectionRepository.addCollectionsInBatch(missing);
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
