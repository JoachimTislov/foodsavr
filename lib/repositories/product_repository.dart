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
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (!snapshot.exists) return;

    final product = Product.fromJson(snapshot.data()!);
    // Discovery happens outside the transaction; the commit below is atomic.
    // A collection created after discovery, or written by a legacy client, is
    // repaired on read (see CollectionService.loadContents).
    final collections = product.isGlobal
        ? const <DocumentReference<Map<String, dynamic>>>[]
        : await _ownerCollectionRefs(product.userId);
    await afterDiscovery?.call();
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(reference);
      final live = await _existing(transaction, collections);
      if (!current.exists) return;
      for (final collection in live) {
        transaction.update(collection, {
          'productIds': FieldValue.arrayRemove([id]),
        });
      }
      transaction.delete(reference);
    });
  }

  Future<List<DocumentReference<Map<String, dynamic>>>> _ownerCollectionRefs(
    String userId,
  ) async {
    final snapshot = await _firestore
        .collection('collections')
        .where('userId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
    return [for (final doc in snapshot.docs) doc.reference];
  }

  /// Keeps the discovered collections that still exist, so a collection
  /// deleted after discovery cannot fail the commit. This reads existence
  /// only; the removals themselves never depend on earlier membership.
  Future<List<DocumentReference<Map<String, dynamic>>>> _existing(
    Transaction transaction,
    Iterable<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    final snapshots = [
      for (final reference in references) await transaction.get(reference),
    ];
    return [
      for (final snapshot in snapshots)
        if (snapshot.exists) snapshot.reference,
    ];
  }

  /// Owner rules deny reading a missing product, so denial means absent.
  Future<bool> _productExists(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    try {
      return (await transaction.get(reference)).exists;
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

    await _firestore.runTransaction((transaction) async {
      final currentSource = await transaction.get(sourceRef);
      if (currentSource.data()?['userId'] != source.userId) {
        throw StateError('The source collection is unavailable.');
      }

      final ids = _productIds(currentSource).toSet();
      final resolvedIds = ids.where(ownedProducts.containsKey).toList();
      // The owner query happened before this transaction. If a new member
      // appeared meanwhile, retry the operation with a fresh product query.
      if (ids.difference(source.productIds.toSet()).isNotEmpty) {
        throw StateError(
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
          throw StateError('The destination inventory is unavailable.');
        }
        // Products deleted after the query must not enter the destination.
        for (final id in resolvedIds) {
          if (!await _productExists(transaction, ownedProducts[id]!)) {
            throw StateError('A product was deleted. Reload and try again.');
          }
        }
        if (resolvedIds.isNotEmpty) {
          transaction.update(targetRef, {
            'productIds': FieldValue.arrayUnion(resolvedIds),
          });
        }
      } else {
        final live = await _existing(transaction, others);
        for (final collection in live) {
          if (resolvedIds.isEmpty) break;
          transaction.update(collection, {
            'productIds': FieldValue.arrayRemove(resolvedIds),
          });
        }
        for (final id in resolvedIds) {
          transaction.delete(ownedProducts[id]!);
        }
      }
      transaction.delete(sourceRef);
    });
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
