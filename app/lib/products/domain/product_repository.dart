import 'package:app/data/models/product_model.dart';

class ProductRepository {
  Future<List<Product>> getProductsForUser(String userId) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Return mock data
    return [
      Product(id: 'p1', name: 'Apple', description: 'Fresh red apple'),
      Product(id: 'p2', name: 'Milk', description: 'Organic whole milk'),
      Product(id: 'p3', name: 'Bread', description: 'Whole wheat bread'),
      Product(id: 'p4', name: 'Eggs', description: 'Farm fresh eggs'),
    ];
  }
}
