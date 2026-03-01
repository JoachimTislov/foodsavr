import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import '../models/product_model.dart';
import '../interfaces/i_product_repository.dart';

@lazySingleton
class ProductService {
  final IProductRepository _productRepository;
  final Logger _logger;

  ProductService(this._productRepository, this._logger);

  /// Fetches all products for a specific user
  /// Returns empty list if userId is null (no user logged in)
  Future<List<Product>> getProducts(String? userId) async {
    if (userId == null) {
      _logger.w('No user logged in, returning empty product list.');
      return [];
    }

    _logger.i('Fetching products for user: $userId');
    try {
      final products = await _productRepository.getProducts(userId);
      _logger.i('Successfully fetched ${products.length} products for user.');
      return products;
    } catch (e) {
      _logger.e('Error fetching user products: $e');
      rethrow;
    }
  }

  /// Returns products for [userId] that are expiring soon (within 6 days) or today.
  Future<List<Product>> getExpiringSoon(String? userId) async {
    final products = await getProducts(userId);
    return products.where((p) => p.isExpiringSoon || p.isExpiringToday).toList()
      ..sort(
        (a, b) =>
            (a.daysUntilExpiration ?? 0).compareTo(b.daysUntilExpiration ?? 0),
      );
  }

  /// Fetches all global products (catalog)
  Future<List<Product>> getAllProducts() async {
    _logger.i('Fetching all global products.');
    try {
      final products = await _productRepository.getGlobalProducts();
      _logger.i('Successfully fetched ${products.length} global products.');
      return products;
    } catch (e) {
      _logger.e('Error fetching global products: $e');
      rethrow;
    }
  }

  Future<Product?> getProductById(int id) async {
    _logger.i('Fetching product by ID: $id');
    try {
      return await _productRepository.get(id);
    } catch (e) {
      _logger.e('Error fetching product: $e');
      rethrow;
    }
  }

  Future<Product> addProduct(Product product) async {
    _logger.i('Adding product: ${product.name}');
    try {
      final addedProduct = await _productRepository.add(product);
      _logger.i('Successfully added product: ${product.name}');
      return addedProduct;
    } catch (e) {
      _logger.e('Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    _logger.i('Updating product: ${product.name}');
    try {
      await _productRepository.update(product);
      _logger.i('Successfully updated product: ${product.name}');
    } catch (e) {
      _logger.e('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(int id) async {
    _logger.i('Deleting product: $id');
    try {
      await _productRepository.delete(id);
      _logger.i('Successfully deleted product: $id');
    } catch (e) {
      _logger.e('Error deleting product: $e');
      rethrow;
    }
  }
}
