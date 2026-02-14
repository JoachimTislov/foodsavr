import 'package:logger/logger.dart';
import '../models/product_model.dart';
import '../interfaces/product_repository.dart';

class ProductService {
  final IProductRepository _productRepository;
  final Logger _logger;

  ProductService(this._productRepository, this._logger);

  Future<List<Product>> getAllProducts() async {
    _logger.i('Fetching all products.');
    try {
      final products = await _productRepository.getAllProducts();
      _logger.i('Successfully fetched ${products.length} products.');
      return products;
    } catch (e) {
      _logger.e('Error fetching all products: $e');
      rethrow;
    }
  }

  Future<List<Product>> getUserProducts(String userId) async {
    _logger.i('Fetching products for user: $userId');
    try {
      final products = await _productRepository.getUserProducts(userId);
      _logger.i('Successfully fetched ${products.length} products for user.');
      return products;
    } catch (e) {
      _logger.e('Error fetching user products: $e');
      rethrow;
    }
  }

  Future<List<Product>> getGlobalProducts() async {
    _logger.i('Fetching global products.');
    try {
      final products = await _productRepository.getGlobalProducts();
      _logger.i('Successfully fetched ${products.length} global products.');
      return products;
    } catch (e) {
      _logger.e('Error fetching global products: $e');
      rethrow;
    }
  }

  Future<Product> addProduct(Product product) async {
    _logger.i('Adding product: ${product.name}');
    try {
      final addedProduct = await _productRepository.addProduct(product);
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
      await _productRepository.updateProduct(product);
      _logger.i('Successfully updated product: ${product.name}');
    } catch (e) {
      _logger.e('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(int id) async {
    _logger.i('Deleting product: $id');
    try {
      await _productRepository.deleteProduct(id);
      _logger.i('Successfully deleted product: $id');
    } catch (e) {
      _logger.e('Error deleting product: $e');
      rethrow;
    }
  }
}
