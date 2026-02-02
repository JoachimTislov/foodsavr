import 'package:app/data/models/product_model.dart';
import 'package:app/products/domain/product_repository.dart';
import 'package:logger/logger.dart';

class ProductService {
  final ProductRepository _productRepository;
  final Logger _logger = Logger();

  ProductService(this._productRepository);

  Future<List<Product>> getProductsForCurrentUser(String userId) async {
    _logger.i('Fetching products for user: $userId');
    try {
      final products = await _productRepository.getProductsForUser(userId);
      _logger.i('Successfully fetched ${products.length} products.');
      return products;
    } catch (e) {
      _logger.e('Error fetching products for user $userId: $e');
      rethrow;
    }
  }
}
