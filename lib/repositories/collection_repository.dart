import '../models/collection_model.dart';
import '../interfaces/collection_repository.dart';

/// In-memory implementation of ICollectionRepository.
/// Used for testing and initial seeding. Data is not persisted.
class InMemoryCollectionRepository implements ICollectionRepository {
  final List<Collection> _collections = [];

  @override
  Future<Collection> addCollection(Collection collection) async {
    _collections.add(collection);
    return collection;
  }

  @override
  Future<Collection?> getCollection(String id) async {
    try {
      return _collections.firstWhere((collection) => collection.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateCollection(Collection collection) async {
    final index = _collections.indexWhere((c) => c.id == collection.id);
    if (index != -1) {
      _collections[index] = collection;
    }
  }

  @override
  Future<void> deleteCollection(String id) async {
    _collections.removeWhere((collection) => collection.id == id);
  }

  @override
  Future<List<Collection>> getAllCollections() async {
    return List.unmodifiable(_collections);
  }
}
