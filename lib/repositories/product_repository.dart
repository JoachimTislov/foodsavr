import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../utils/collection_types.dart';
import '../interfaces/i_product_repository.dart';

@LazySingleton(as: IProductRepository)
class ProductRepository implements IProductRepository {
  final FirebaseFirestore _firestore;
  final String _collectionName = 'products';

  /// Runs between discovery and the atomic commit of a delete, so tests can
  /// interleave a membership write.
  @visibleForTesting
  Future<void> Function()? afterDiscovery;

  ProductRepository(this._firestore);

  @override
  Future<Product> add(Product product) async {
    final docRef = product.id.isEmpty
        ? _firestore.collection(_collectionName).doc()
        : _firestore.collection(_collectionName).doc(product.id);
    final savedProduct = product.id.isEmpty
        ? product.copyWith(id: docRef.id)
        : product;
    await docRef.set(savedProduct.toJson());
    return savedProduct;
  }

  @override
  Future<Product?> get(String id) async {
    final doc = await _firestore
        .collection(_collectionName)
        .doc(id.toString())
        .get();
    if (!doc.exists) return null;
    return Product.fromJson(doc.data()!);
  }

  @override
  Future<void> update(Product product) async {
    await _firestore
        .collection(_collectionName)
        .doc(product.id)
        .update(product.toJson());
  }

  @override
  Future<void> delete(String id) async {
    final reference = _firestore.collection(_collectionName).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) return;

    final product = Product.fromJson(snapshot.data()!);
    // Discovery can use the local cache. The batch queues offline and its
    // Future completes on server acknowledgement.
    // A collection created after discovery, or written by a legacy client, is
    // repaired on read (see CollectionService.loadContents).
    final collections = product.isGlobal
        ? const <DocumentReference<Map<String, dynamic>>>[]
        : await _ownerCollectionRefs(product.userId, serverOnly: false);
    await afterDiscovery?.call();
    try {
      await _commitProductDelete(reference, collections);
    } on FirebaseException catch (e) {
      // An update against a collection removed since discovery can reject
      // the entire queued batch. Retry only after confirming that a discovered
      // collection is gone. Firestore itself retries transient failures.
      if (collections.isEmpty ||
          (e.code != 'not-found' && e.code != 'permission-denied')) {
        rethrow;
      }
      final current = await _ownerCollectionRefs(product.userId);
      if (collections.every(current.contains)) rethrow;
      await _commitProductDelete(reference, current);
    }
  }

  Future<void> _commitProductDelete(
    DocumentReference<Map<String, dynamic>> product,
    List<DocumentReference<Map<String, dynamic>>> collections,
  ) {
    final batch = _firestore.batch();
    for (final collection in collections) {
      batch.update(collection, {
        'productIds': FieldValue.arrayRemove([product.id]),
      });
    }
    batch.delete(product);
    return batch.commit();
  }

  Future<List<DocumentReference<Map<String, dynamic>>>> _ownerCollectionRefs(
    String userId, {
    bool serverOnly = true,
  }) async {
    final snapshot = await _firestore
        .collection('collections')
        .where('userId', isEqualTo: userId)
        .get(serverOnly ? const GetOptions(source: Source.server) : null);
    return [for (final doc in snapshot.docs) doc.reference];
  }

  /// Resolves memberships from the current versions of discovered siblings.
  Future<Set<String>> _siblingProductIds(
    Transaction transaction,
    Iterable<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    final ids = <String>{};
    for (final reference in references) {
      try {
        ids.addAll(_productIds(await transaction.get(reference)));
      } on FirebaseException catch (e) {
        // The owner query established access at discovery. The read rules
        // deny a document get if that sibling has since been deleted.
        if (e.code != 'permission-denied') rethrow;
      }
    }
    return ids;
  }

  /// A missing or inaccessible product cannot be moved or deleted.
  Future<bool> _isOwnedProduct(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> reference,
    String owner,
  ) async {
    try {
      final data = (await transaction.get(reference)).data();
      return data?['userId'] == owner && data?['isGlobal'] != true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  List<String> _productIds(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      List<String>.from(snapshot.data()?['productIds'] as List? ?? const []);

  @override
  Future<void> deleteCollection(
    Collection source, {
    String? destinationId,
  }) async {
    if (destinationId == source.id) {
      throw ArgumentError('The destination must differ from the source.');
    }

    final collections = _firestore.collection('collections');
    final sourceRef = collections.doc(source.id);
    if (source.type == CollectionType.shoppingList) {
      if (destinationId != null) {
        throw ArgumentError('Shopping list products cannot be moved.');
      }
      await sourceRef.delete();
      return;
    }
    final products = await _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: source.userId)
        .get(const GetOptions(source: Source.server));
    final ownedProducts = {
      for (final doc in products.docs)
        if (doc.data()['isGlobal'] != true) doc.id: doc.reference,
    };
    final others = destinationId == null
        ? [
            for (final reference in await _ownerCollectionRefs(source.userId))
              if (reference.id != source.id) reference,
          ]
        : const <DocumentReference<Map<String, dynamic>>>[];
    await afterDiscovery?.call();

    // Return validation errors through the transaction so the Dart type and
    // message survive FlutterFire Web's JavaScript boundary.
    final error = await _firestore.runTransaction<StateError?>((
      transaction,
    ) async {
      final currentSource = await transaction.get(sourceRef);
      if (currentSource.data()?['userId'] != source.userId) {
        return StateError('The source collection is unavailable.');
      }

      if (currentSource.data()?['type'] == CollectionType.shoppingList.name) {
        return StateError('The source is no longer an inventory.');
      }
      final ids = _productIds(currentSource).toSet();
      final resolvedIds = ids.where(ownedProducts.containsKey).toList();
      // The owner query happened before this transaction. If a new member
      // appeared meanwhile, retry the operation with a fresh product query.
      if (ids.difference(source.productIds.toSet()).isNotEmpty) {
        return StateError(
          'Collection membership changed. Reload and try again.',
        );
      }

      if (destinationId != null) {
        final targetRef = collections.doc(destinationId);
        final target = await transaction.get(targetRef);
        final data = target.data();
        if (data?['userId'] != source.userId ||
            (data?['type'] ?? CollectionType.inventory.name) !=
                CollectionType.inventory.name) {
          return StateError('The destination inventory is unavailable.');
        }
        // Products deleted after the query must not enter the destination.
        for (final id in resolvedIds) {
          if (!await _isOwnedProduct(
            transaction,
            ownedProducts[id]!,
            source.userId,
          )) {
            return StateError('A product was deleted. Reload and try again.');
          }
        }
        if (resolvedIds.isNotEmpty) {
          transaction.update(targetRef, {
            'productIds': FieldValue.arrayUnion(resolvedIds),
          });
        }
      } else {
        final sharedIds = await _siblingProductIds(transaction, others);
        final deletable = [
          for (final id in resolvedIds)
            if (!sharedIds.contains(id) &&
                await _isOwnedProduct(
                  transaction,
                  ownedProducts[id]!,
                  source.userId,
                ))
              id,
        ];
        for (final id in deletable) {
          transaction.delete(ownedProducts[id]!);
        }
      }
      transaction.delete(sourceRef);
      return null;
    });
    if (error != null) throw error;
  }

  @override
  Future<List<Product>> getProducts(String userId) async {
    final querySnapshot = await _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .where('isGlobal', isEqualTo: false)
        .get();
    return querySnapshot.docs
        .map((doc) => Product.fromJson(doc.data()))
        .where((product) => product.registryType != 'personal')
        .toList();
  }

  @override
  Future<List<Product>> getPersonalProducts(String userId) async {
    final querySnapshot = await _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .where('registryType', isEqualTo: 'personal')
        .get();
    return querySnapshot.docs
        .map((doc) => Product.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<List<Product>> getGlobalProducts() async {
    final querySnapshot = await _firestore
        .collection(_collectionName)
        .where('isGlobal', isEqualTo: true)
        .get();
    return querySnapshot.docs
        .map((doc) => Product.fromJson(doc.data()))
        .toList();
  }
}
