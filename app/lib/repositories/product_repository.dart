import '../models/product_model.dart';

class ProductRepository {
  final List<Product> _products = [];

  // Product methods
  Future<Product> addProduct(Product product) async {
    _products.add(product);
    return product;
  }

  Future<Product?> getProduct(int id) async {
    return _products.firstWhere((product) => product.id == id);
  }

  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
    }
  }

  Future<void> deleteProduct(int id) async {
    _products.removeWhere((product) => product.id == id);
  }

  Future<List<Product>> getAllProducts() async {
    return _products;
  }
}
