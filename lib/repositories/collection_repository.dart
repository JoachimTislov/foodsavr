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

  /// Returns a validation error before any membership write is staged.
  Future<StateError?> _validateOwnedProducts(
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
        return StateError('Product $id is unavailable. Reload and try again.');
      }
    }
    return null;
  }

  Future<void> _writeMembership(
    Future<StateError?> Function(Transaction) write,
  ) async {
    // Keep domain errors outside the SDK callback so FlutterFire Web preserves
    // their type and message across the JavaScript boundary.
    final error = await _firestore.runTransaction(write);
    if (error != null) throw error;
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
    await _writeMembership((transaction) async {
      final error = await _validateOwnedProducts(
        transaction,
        savedCollection.userId,
        savedCollection.productIds,
      );
      if (error != null) return error;
      await afterMembershipRead?.call();
      transaction.set(docRef, savedCollection.toJson());
      return null;
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
  Future<void> update(
    Collection collection, {
    bool metadataOnly = false,
  }) async {
    final docRef = _firestore.collection(_collectionName).doc(collection.id);
    await _writeMembership((transaction) async {
      final current = await transaction.get(docRef);
      if (!current.exists) return StateError('The collection is unavailable.');
      if (metadataOnly) {
        final metadata = collection.toJson()..remove('productIds');
        transaction.update(docRef, metadata);
        return null;
      }
      // Only IDs this write introduces must resolve; legacy IDs may remain.
      final existing = List<String>.from(
        current.data()?['productIds'] as List? ?? const [],
      ).toSet();
      final error = await _validateOwnedProducts(
        transaction,
        collection.userId,
        collection.productIds.toSet().difference(existing),
      );
      if (error != null) return error;
      await afterMembershipRead?.call();
      transaction.update(docRef, collection.toJson());
      return null;
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
  Future<({List<Product> products, bool authoritative})> getMemberProducts(
    String userId,
  ) async {
    // A direct get of a missing document cannot satisfy the owner read rule.
    final snapshot = await _firestore
        .collection('products')
        .where('userId', isEqualTo: userId)
        .get();
    return (
      products: snapshot.docs
          .map((doc) => Product.fromJson(doc.data()))
          .where((product) => !product.isGlobal)
          .toList(),
      authoritative:
          !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites,
    );
  }

  @override
  Future<void> addProduct(String collectionId, String productId) =>
      addProducts(collectionId, [productId]);

  @override
  Future<void> addProducts(String collectionId, List<String> productIds) async {
    if (productIds.isEmpty) return;
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await _writeMembership((transaction) async {
      final collection = await transaction.get(docRef);
      final userId = collection.data()?['userId'];
      if (userId is! String) {
        return StateError('The collection is unavailable.');
      }
      final error = await _validateOwnedProducts(
        transaction,
        userId,
        productIds,
      );
      if (error != null) return error;
      await afterMembershipRead?.call();
      transaction.update(docRef, {
        'productIds': FieldValue.arrayUnion(productIds),
      });
      return null;
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
    final writes = [
      for (final collection in collections)
        (
          reference: _firestore
              .collection(_collectionName)
              .doc(collection.id.isEmpty ? null : collection.id),
          collection: collection,
        ),
    ];
    if (collections.any((collection) => collection.productIds.isNotEmpty)) {
      await _writeMembership((transaction) async {
        for (final collection in collections) {
          final error = await _validateOwnedProducts(
            transaction,
            collection.userId,
            collection.productIds,
          );
          if (error != null) return error;
        }
        await afterMembershipRead?.call();
        for (final (:reference, :collection) in writes) {
          transaction.set(
            reference,
            collection.copyWith(id: reference.id).toJson(),
          );
        }
        return null;
      });
      return;
    }

    final batch = _firestore.batch();
    for (final (:reference, :collection) in writes) {
      batch.set(reference, collection.copyWith(id: reference.id).toJson());
    }
    await batch.commit();
  }
}
