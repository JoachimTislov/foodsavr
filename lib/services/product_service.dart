import 'package:app/models/product_model.dart';
import 'package:app/interfaces/product_repository.dart';
import 'package:logger/logger.dart';

class ProductService {
  final IProductRepository _productRepository;
  final Logger _logger = Logger();

  ProductService(this._productRepository);

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
}
