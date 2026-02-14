import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/collection_model.dart';
import '../interfaces/collection_repository_interface.dart';

/// Firestore implementation of ICollectionRepository.
/// Persists collection data in Firestore 'collections' collection.
class CollectionRepository implements ICollectionRepository {
  final FirebaseFirestore _firestore;
  final String _collectionName = 'collections';

  CollectionRepository(this._firestore);

  @override
  Future<Collection> addCollection(Collection collection) async {
    await _firestore
        .collection(_collectionName)
        .doc(collection.id)
        .set(collection.toJson());
    return collection;
  }

  @override
  Future<Collection?> getCollection(String id) async {
    final doc = await _firestore.collection(_collectionName).doc(id).get();
    if (!doc.exists) return null;
    return Collection.fromJson(doc.data()!);
  }

  @override
  Future<void> updateCollection(Collection collection) async {
    await _firestore
        .collection(_collectionName)
        .doc(collection.id)
        .update(collection.toJson());
  }

  @override
  Future<void> deleteCollection(String id) async {
    await _firestore.collection(_collectionName).doc(id).delete();
  }

  @override
  Future<List<Collection>> getAllCollections() async {
    final querySnapshot = await _firestore.collection(_collectionName).get();
    return querySnapshot.docs
        .map((doc) => Collection.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<List<Collection>> getUserCollections(String userId) async {
    final querySnapshot = await _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .get();
    return querySnapshot.docs
        .map((doc) => Collection.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> addProductToCollection(String collectionId, int productId) async {
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await docRef.update({
      'productIds': FieldValue.arrayUnion([productId]),
    });
  }

  @override
  Future<void> removeProductFromCollection(String collectionId, int productId) async {
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await docRef.update({
      'productIds': FieldValue.arrayRemove([productId]),
    });
  }
}
