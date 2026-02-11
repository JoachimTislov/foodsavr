import 'package:logger/logger.dart';
import '../models/product_model.dart';
import '../interfaces/product_repository.dart';

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
