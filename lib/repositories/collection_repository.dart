import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  /// Runs after membership products were read and before the commit, so tests
  /// can interleave a delete with the transaction.
  @visibleForTesting
  Future<void> Function()? afterMembershipRead;

  CollectionRepository(this._firestore);

  /// Reads every referenced product inside [transaction]. A missing, global,
  /// or foreign product aborts the transaction before any membership write.
  Future<void> _requireOwnedProducts(
    Transaction transaction,
    String userId,
    Iterable<String> productIds,
  ) async {
    for (final id in productIds.toSet()) {
      Map<String, dynamic>? data;
      try {
        data = (await transaction.get(
          _firestore.collection('products').doc(id),
        )).data();
      } on FirebaseException catch (e) {
        // Owner rules deny reading a missing product.
        if (e.code != 'permission-denied') rethrow;
      }
      if (data == null ||
          data['userId'] != userId ||
          data['isGlobal'] == true) {
        throw StateError('Product $id is unavailable. Reload and try again.');
      }
    }
  }

  @override
  Future<Collection> add(Collection collection) async {
    final docRef = collection.id.isEmpty
        ? _firestore.collection(_collectionName).doc()
        : _firestore.collection(_collectionName).doc(collection.id);
    final savedCollection = collection.id.isEmpty
        ? collection.copyWith(id: docRef.id)
        : collection;
    if (savedCollection.productIds.isEmpty) {
      await docRef.set(savedCollection.toJson());
      return savedCollection;
    }
    await _firestore.runTransaction((transaction) async {
      await _requireOwnedProducts(
        transaction,
        savedCollection.userId,
        savedCollection.productIds,
      );
      await afterMembershipRead?.call();
      transaction.set(docRef, savedCollection.toJson());
    });
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
    final docRef = _firestore.collection(_collectionName).doc(collection.id);
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(docRef);
      if (!current.exists) throw StateError('The collection is unavailable.');
      // Only IDs this write introduces must resolve; legacy IDs may remain.
      final existing = List<String>.from(
        current.data()?['productIds'] as List? ?? const [],
      ).toSet();
      await _requireOwnedProducts(
        transaction,
        collection.userId,
        collection.productIds.toSet().difference(existing),
      );
      await afterMembershipRead?.call();
      transaction.update(docRef, collection.toJson());
    });
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
  Future<void> addProduct(String collectionId, String productId) =>
      addProducts(collectionId, [productId]);

  @override
  Future<void> addProducts(String collectionId, List<String> productIds) async {
    if (productIds.isEmpty) return;
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await _firestore.runTransaction((transaction) async {
      final collection = await transaction.get(docRef);
      final userId = collection.data()?['userId'];
      if (userId is! String) throw StateError('The collection is unavailable.');
      await _requireOwnedProducts(transaction, userId, productIds);
      await afterMembershipRead?.call();
      transaction.update(docRef, {
        'productIds': FieldValue.arrayUnion(productIds),
      });
    });
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
