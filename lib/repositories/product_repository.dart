import '../models/product_model.dart';
import '../interfaces/product_repository.dart';

/// In-memory implementation of IProductRepository.
/// Used for testing and initial seeding. Data is not persisted.
class InMemoryProductRepository implements IProductRepository {
  final List<Product> _products = [];

  @override
  Future<Product> addProduct(Product product) async {
    _products.add(product);
    return product;
  }

  @override
  Future<Product?> getProduct(int id) async {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
    }
  }

  @override
  Future<void> deleteProduct(int id) async {
    _products.removeWhere((product) => product.id == id);
  }

  @override
  Future<List<Product>> getAllProducts() async {
    return List.unmodifiable(_products);
  }
}
