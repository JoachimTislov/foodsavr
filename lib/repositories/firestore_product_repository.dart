import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../interfaces/product_repository.dart';

/// Firestore implementation of IProductRepository.
/// Persists product data in Firestore 'products' collection.
class FirestoreProductRepository implements IProductRepository {
  final FirebaseFirestore _firestore;
  final String _collectionName = 'products';

  FirestoreProductRepository(this._firestore);

  @override
  Future<Product> addProduct(Product product) async {
    await _firestore
        .collection(_collectionName)
        .doc(product.id.toString())
        .set(product.toJson());
    return product;
  }

  @override
  Future<Product?> getProduct(int id) async {
    final doc = await _firestore
        .collection(_collectionName)
        .doc(id.toString())
        .get();
    if (!doc.exists) return null;
    return Product.fromJson(doc.data()!);
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _firestore
        .collection(_collectionName)
        .doc(product.id.toString())
        .update(product.toJson());
  }

  @override
  Future<void> deleteProduct(int id) async {
    await _firestore.collection(_collectionName).doc(id.toString()).delete();
  }

  @override
  Future<List<Product>> getAllProducts() async {
    final querySnapshot = await _firestore.collection(_collectionName).get();
    return querySnapshot.docs
        .map((doc) => Product.fromJson(doc.data()))
        .toList();
  }
}
