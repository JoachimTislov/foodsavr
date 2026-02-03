import '../models/collection_model.dart';

class CollectionRepository {
  final List<Collection> _collections = [];

  // Collection methods
  Future<Collection> addCollection(Collection collection) async {
    _collections.add(collection);
    return collection;
  }

  Future<Collection?> getCollection(String id) async {
    return _collections.firstWhere((collection) => collection.id == id);
  }

  Future<void> updateCollection(Collection collection) async {
    final index = _collections.indexWhere((c) => c.id == collection.id);
    if (index != -1) {
      _collections[index] = collection;
    }
  }

  Future<void> deleteCollection(String id) async {
    _collections.removeWhere((collection) => collection.id == id);
  }
}
