import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../utils/collection_types.dart';
import '../interfaces/i_product_repository.dart';

@LazySingleton(as: IProductRepository)
class ProductRepository implements IProductRepository {
  final FirebaseFirestore _firestore;
  final String _collectionName = 'products';

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
    final batch = _firestore.batch();
    if (!product.isGlobal) {
      for (final collection in await _ownerCollections(product.userId)) {
        if (_productIds(collection).contains(id)) {
          batch.update(collection.reference, {
            'productIds': FieldValue.arrayRemove([id]),
          });
        }
      }
    }
    batch.delete(reference);
    await batch.commit();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _ownerCollections(
    String userId,
  ) async {
    final snapshot = await _firestore
        .collection('collections')
        .where('userId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs;
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
    final otherCollections = destinationId == null
        ? await _ownerCollections(source.userId)
        : const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

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
        if (resolvedIds.isNotEmpty) {
          transaction.update(targetRef, {
            'productIds': FieldValue.arrayUnion(resolvedIds),
          });
        }
      } else {
        final deletedIds = resolvedIds.toSet();
        for (final collection in otherCollections) {
          if (collection.id == source.id) continue;
          final removed = _productIds(collection).where(deletedIds.contains);
          if (removed.isNotEmpty) {
            transaction.update(collection.reference, {
              'productIds': FieldValue.arrayRemove(removed.toList()),
            });
          }
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
