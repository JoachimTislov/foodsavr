import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../interfaces/i_collection_repository.dart';
import '../services/sync_status.dart';

/// Firestore implementation of ICollectionRepository.
/// Persists collection data in Firestore 'collections' collection.
@LazySingleton(as: ICollectionRepository)
class CollectionRepository implements ICollectionRepository {
  final FirebaseFirestore _firestore;
  final String _collectionName = 'collections';
  static const _membershipTimeout = Duration(seconds: 2);
  static const _transactionTimeout = Duration(seconds: 30);
  static const _offlineCodes = {'unavailable', 'deadline-exceeded'};

  /// Runs after membership products were read and before the commit, so tests
  /// can interleave a delete with the transaction.
  @visibleForTesting
  Future<void> Function()? afterMembershipRead;

  /// Runs after a membership transaction staged its writes and before it
  /// returns them for commit, so tests can delay the commit.
  @visibleForTesting
  Future<void> Function()? beforeMembershipCommit;

  /// Runs before a read-repair prune starts its transaction.
  @visibleForTesting
  Future<void> Function()? beforeDanglingPrune;

  /// Counts membership writes queued offline.
  final SyncStatus _syncStatus;

  CollectionRepository(this._firestore, this._syncStatus);

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

  /// Verifies products and writes membership in one transaction. With
  /// [queue], a server that is unreachable, or slower than
  /// [_membershipTimeout] before any write is staged, falls back to [queue],
  /// the queued write that works offline. Permission and validation errors
  /// never fall back.
  ///
  /// Once an attempt has staged its writes, the call waits for the real
  /// outcome instead of falling back: a late commit must never land after a
  /// reported success and overwrite a later edit. After a fallback, no attempt,
  /// retries included, can stage a write.
  Future<void> _writeMembership(
    Future<StateError?> Function(Transaction, Set<String>, VoidCallback)
    write, {
    Future<void> Function()? queue,
  }) async {
    final verifiedProducts = <String>{};
    var readyToCommit = false;
    var staged = false;
    var expired = false;
    // Stops an attempt from staging writes after a fallback, and records that
    // an attempt staged them.
    void checkDeadline() {
      if (expired) throw TimeoutException('Membership transaction expired.');
      staged = true;
    }

    // Return validation errors through the callback to preserve their Dart
    // type on FlutterFire Web.
    final transaction = _firestore.runTransaction((transaction) async {
      if (expired) throw TimeoutException('Membership transaction expired.');
      verifiedProducts.clear();
      readyToCommit = false;
      final validationError = await write(
        transaction,
        verifiedProducts,
        checkDeadline,
      );
      if (validationError == null) await beforeMembershipCommit?.call();
      readyToCommit = validationError == null;
      return validationError;
    }, timeout: _transactionTimeout);
    StateError? error;
    try {
      if (queue == null) {
        error = await transaction;
      } else {
        final deadline = Completer<void>();
        final timer = Timer(_membershipTimeout, deadline.complete);
        final ({StateError? error})? outcome;
        try {
          outcome = await Future.any([
            transaction.then((error) => (error: error)),
            deadline.future.then((_) => null),
          ]);
        } finally {
          timer.cancel();
        }
        expired = outcome == null && !staged;
        if (!expired) {
          error = outcome == null ? await transaction : outcome.error;
        }
      }
    } on TimeoutException {
      if (queue == null || staged) rethrow;
      return queue();
    } on FirebaseException catch (e) {
      // Native platforms report the transaction timeout as deadline-exceeded.
      if (queue != null && !staged && _offlineCodes.contains(e.code)) {
        return queue();
      }
      if (!readyToCommit || e.code != 'permission-denied') rethrow;
      // A product can disappear after its transaction read. A server get
      // distinguishes that race from a denied collection write.
      for (final id in verifiedProducts) {
        if (await isProductMissingOrUnreadable(id)) {
          throw _unavailableProduct(id);
        }
      }
      rethrow;
    }
    if (expired) {
      unawaited(transaction.then<void>((_) {}, onError: (_) {}));
      return queue!();
    }
    if (error != null) throw error;
  }

  /// Issues the unverified arrayUnion [write] that Firestore queues offline.
  /// It returns once the server acknowledges it, or after
  /// [SyncStatus.acknowledgementTimeout] while the write stays queued.
  ///
  /// A queued add can leave a dangling ID when it races a delete or names a
  /// foreign product; server reads hide and repair such references. A write
  /// the server rejects later is rolled back in the local cache and never
  /// replayed.
  Future<void> _queueMembership(Future<void> Function() write) =>
      _syncStatus.queue(write);

  @override
  Future<bool> isProductMissingOrUnreadable(String id) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .doc(id)
          .get(const GetOptions(source: Source.server));
      return !snapshot.exists &&
          !snapshot.metadata.isFromCache &&
          !snapshot.metadata.hasPendingWrites;
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
    await _writeMembership(
      (transaction, verifiedProducts, checkDeadline) async {
        final error = await _validateOwnedProducts(
          transaction,
          savedCollection.userId,
          savedCollection.productIds,
          verifiedProducts,
        );
        if (error != null) return error;
        await afterMembershipRead?.call();
        checkDeadline();
        transaction.set(docRef, savedCollection.toJson());
        return null;
      },
      queue: () => _queueMembership(
        () => docRef.set({
          ...savedCollection.toJson(),
          'productIds': FieldValue.arrayUnion(savedCollection.productIds),
        }, SetOptions(merge: true)),
      ),
    );
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
    await _writeMembership((
      transaction,
      verifiedProducts,
      checkDeadline,
    ) async {
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
      checkDeadline();
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
    final membership = {'productIds': FieldValue.arrayUnion(productIds)};
    await _writeMembership((
      transaction,
      verifiedProducts,
      checkDeadline,
    ) async {
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
      checkDeadline();
      transaction.update(docRef, membership);
      return null;
    }, queue: () => _queueMembership(() => docRef.update(membership)));
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
    final removal = {'productIds': FieldValue.arrayRemove(productIds.toList())};
    // Offline, the write lands in the local cache and syncs on reconnect.
    await _queueMembership(() => docRef.update(removal));
  }

  @override
  Future<void> pruneMissingProducts(
    String collectionId,
    Iterable<String> productIds,
  ) async {
    final docRef = _firestore.collection(_collectionName).doc(collectionId);
    await beforeDanglingPrune?.call();
    await _firestore
        .runTransaction((transaction) async {
          // Read the collection first in every attempt. A missing product reads as
          // permission-denied and stays out of the read set, so a concurrent write
          // to the collection is what makes the commit conflict and retry.
          final members = _memberIds(await transaction.get(docRef));
          final missing = <String>[];
          for (final id in productIds.toSet().where(members.contains)) {
            try {
              final product = await transaction.get(
                _firestore.collection('products').doc(id),
              );
              if (!product.exists) missing.add(id);
            } on FirebaseException catch (e) {
              if (e.code != 'permission-denied') rethrow;
              missing.add(id);
            }
          }
          if (missing.isEmpty) return;
          transaction.update(docRef, {
            'productIds': FieldValue.arrayRemove(missing),
          });
        }, timeout: _transactionTimeout)
        .timeout(_membershipTimeout);
  }

  List<String> _memberIds(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      List<String>.from(snapshot.data()?['productIds'] as List? ?? const []);

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
      await _writeMembership(
        (transaction, verifiedProducts, checkDeadline) async {
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
          checkDeadline();
          for (final (:reference, :collection) in writes) {
            transaction.set(
              reference,
              collection.copyWith(id: reference.id).toJson(),
            );
          }
          return null;
        },
        queue: () => _queueMembership(() {
          final batch = _firestore.batch();
          for (final (:reference, :collection) in writes) {
            final data = collection.copyWith(id: reference.id).toJson();
            data['productIds'] = FieldValue.arrayUnion(collection.productIds);
            batch.set(reference, data, SetOptions(merge: true));
          }
          return batch.commit();
        }),
      );
      return;
    }

    final batch = _firestore.batch();
    for (final (:reference, :collection) in writes) {
      batch.set(reference, collection.copyWith(id: reference.id).toJson());
    }
    await batch.commit();
  }
}
