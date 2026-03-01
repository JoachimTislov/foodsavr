import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import '../models/collection_model.dart';
import '../interfaces/i_collection_repository.dart';

/// Firestore implementation of ICollectionRepository.
/// Persists collection data in Firestore 'collections' collection.
@LazySingleton(as: ICollectionRepository)
class CollectionRepository implements ICollectionRepository {
  final FirebaseFirestore _firestore;
  final String _collectionName = 'collections';

  CollectionRepository(this._firestore);

  @override
  Future<Collection> add(Collection collection) async {
    final docRef = collection.id.isEmpty
        ? _firestore.collection(_collectionName).doc()
        : _firestore.collection(_collectionName).doc(collection.id);
    final savedCollection = collection.id.isEmpty
        ? collection.copyWith(id: docRef.id)
        : collection;
    await docRef.set(savedCollection.toJson());
    return savedCollection;
  }

  @override
  Future<Collection?> get(String id) async {
    final doc = await _firestore.collection(_collectionName).doc(id).get();
    if (!doc.exists) return null;
    return Collection.fromJson(doc.data()!);
  }

  @override
  Future<void> update(Collection collection) async {
    await _firestore
        .collection(_collectionName)
        .doc(collection.id)
        .update(collection.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _firestore.collection(_collectionName).doc(id).delete();
  }

  @override
  Future<List<Collection>> getAll() async {
    final querySnapshot = await _firestore.collection(_collectionName).get();
    return querySnapshot.docs
        .map((doc) => Collection.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<List<Collection>> getCollections(String userId) async {
    final querySnapshot = await _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .get();
    return querySnapshot.docs
        .map((doc) => Collection.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> addProduct(String collectionId, int productId) async {
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await docRef.update({
      'productIds': FieldValue.arrayUnion([productId]),
    });
  }

  @override
  Future<void> addProducts(String collectionId, List<int> productIds) async {
    if (productIds.isEmpty) return;
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await docRef.update({'productIds': FieldValue.arrayUnion(productIds)});
  }

  @override
  Future<void> removeProduct(String collectionId, int productId) async {
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await docRef.update({
      'productIds': FieldValue.arrayRemove([productId]),
    });
  }
}
