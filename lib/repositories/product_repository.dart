import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../models/product_model.dart';
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
    await _firestore.collection(_collectionName).doc(id.toString()).delete();
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
