import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../models/collection_model.dart';
import '../models/product_model.dart';
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
  Future<List<Collection>> getCollections(
    String userId, {
    bool serverOnly = false,
  }) async {
    final querySnapshot = await _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .get(serverOnly ? const GetOptions(source: Source.server) : null);
    return querySnapshot.docs
        .map((doc) => Collection.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<List<Product>> getMemberProducts(String userId) async {
    // A direct get of a missing document cannot satisfy the owner read rule.
    final snapshot = await _firestore
        .collection('products')
        .where('userId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => Product.fromJson(doc.data()))
        .where((product) => !product.isGlobal)
        .toList();
  }

  @override
  Future<void> addProduct(String collectionId, String productId) async {
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await docRef.update({
      'productIds': FieldValue.arrayUnion([productId]),
    });
  }

  @override
  Future<void> addProducts(String collectionId, List<String> productIds) async {
    if (productIds.isEmpty) return;
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await docRef.update({'productIds': FieldValue.arrayUnion(productIds)});
  }

  @override
  Future<void> removeProduct(String collectionId, String productId) =>
      removeProducts(collectionId, [productId]);

  @override
  Future<void> removeProducts(
    String collectionId,
    Iterable<String> productIds,
  ) async {
    if (productIds.isEmpty) return;
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await docRef.update({
      'productIds': FieldValue.arrayRemove(productIds.toList()),
    });
  }

  @override
  Future<void> addCollectionsInBatch(List<Collection> collections) async {
    final batch = _firestore.batch();
    for (var collection in collections) {
      final docRef = collection.id.isEmpty
          ? _firestore.collection(_collectionName).doc()
          : _firestore.collection(_collectionName).doc(collection.id);
      final savedCollection = collection.id.isEmpty
          ? collection.copyWith(id: docRef.id)
          : collection;
      batch.set(docRef, savedCollection.toJson());
    }
    await batch.commit();
  }
}
