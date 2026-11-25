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
    Set<String> verifiedProducts,
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
        return _unavailableProduct(id);
      }
      verifiedProducts.add(id);
    }
    return null;
  }

  StateError _unavailableProduct(String id) =>
      StateError('Product $id is unavailable. Reload and try again.');

  Future<void> _writeMembership(
    Future<StateError?> Function(Transaction, Set<String>) write,
  ) async {
    final verifiedProducts = <String>{};
    var readyToCommit = false;
    StateError? error;
    try {
      // Return validation errors through the callback to preserve their Dart
      // type on FlutterFire Web.
      error = await _firestore.runTransaction((transaction) async {
        verifiedProducts.clear();
        readyToCommit = false;
        final validationError = await write(transaction, verifiedProducts);
        readyToCommit = validationError == null;
        return validationError;
      });
    } on FirebaseException catch (e) {
      if (!readyToCommit || e.code != 'permission-denied') rethrow;
      // A product can disappear after its transaction read. A server get
      // distinguishes that race from a denied collection write.
      for (final id in verifiedProducts) {
        if (await _isProductMissingOrUnreadable(id)) {
          throw _unavailableProduct(id);
        }
      }
      rethrow;
    }
    if (error != null) throw error;
  }

  Future<bool> _isProductMissingOrUnreadable(String id) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .doc(id)
          .get(const GetOptions(source: Source.server));
      return !snapshot.exists;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied';
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
    await _writeMembership((transaction, verifiedProducts) async {
      final error = await _validateOwnedProducts(
        transaction,
        savedCollection.userId,
        savedCollection.productIds,
        verifiedProducts,
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
    if (metadataOnly) {
      await docRef.update(collection.toJson()..remove('productIds'));
      return;
    }
    await _writeMembership((transaction, verifiedProducts) async {
      final current = await transaction.get(docRef);
      if (!current.exists) return StateError('The collection is unavailable.');
      // Only IDs this write introduces must resolve; legacy IDs may remain.
      final existing = List<String>.from(
        current.data()?['productIds'] as List? ?? const [],
      ).toSet();
      final error = await _validateOwnedProducts(
        transaction,
        collection.userId,
        collection.productIds.toSet().difference(existing),
        verifiedProducts,
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
    await _writeMembership((transaction, verifiedProducts) async {
      final collection = await transaction.get(docRef);
      final userId = collection.data()?['userId'];
      if (userId is! String) {
        return StateError('The collection is unavailable.');
      }
      final error = await _validateOwnedProducts(
        transaction,
        userId,
        productIds,
        verifiedProducts,
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
      await _writeMembership((transaction, verifiedProducts) async {
        for (final collection in collections) {
          final error = await _validateOwnedProducts(
            transaction,
            collection.userId,
            collection.productIds,
            verifiedProducts,
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
