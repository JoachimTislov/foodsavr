import 'package:logger/logger.dart';
import '../models/collection_model.dart';
import '../interfaces/collection_repository.dart';

class CollectionService {
  final ICollectionRepository _collectionRepository;
  final Logger _logger;

  CollectionService(this._collectionRepository, this._logger);

  Future<List<Collection>> getAllCollections() async {
    _logger.i('Fetching all collections.');
    try {
      final collections = await _collectionRepository.getAllCollections();
      _logger.i('Successfully fetched ${collections.length} collections.');
      return collections;
    } catch (e) {
      _logger.e('Error fetching all collections: $e');
      rethrow;
    }
  }

  Future<List<Collection>> getUserCollections(String userId) async {
    _logger.i('Fetching collections for user: $userId');
    try {
      final collections = await _collectionRepository.getUserCollections(userId);
      _logger.i('Successfully fetched ${collections.length} collections for user.');
      return collections;
    } catch (e) {
      _logger.e('Error fetching user collections: $e');
      rethrow;
    }
  }

  Future<Collection> addCollection(Collection collection) async {
    _logger.i('Adding collection: ${collection.name}');
    try {
      final addedCollection = await _collectionRepository.addCollection(collection);
      _logger.i('Successfully added collection: ${collection.name}');
      return addedCollection;
    } catch (e) {
      _logger.e('Error adding collection: $e');
      rethrow;
    }
  }

  Future<void> updateCollection(Collection collection) async {
    _logger.i('Updating collection: ${collection.name}');
    try {
      await _collectionRepository.updateCollection(collection);
      _logger.i('Successfully updated collection: ${collection.name}');
    } catch (e) {
      _logger.e('Error updating collection: $e');
      rethrow;
    }
  }

  Future<void> deleteCollection(String id) async {
    _logger.i('Deleting collection: $id');
    try {
      await _collectionRepository.deleteCollection(id);
      _logger.i('Successfully deleted collection: $id');
    } catch (e) {
      _logger.e('Error deleting collection: $e');
      rethrow;
    }
  }
}
