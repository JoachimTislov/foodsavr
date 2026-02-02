import 'database.dart';
import '../authentication/domain/user.dart';
import 'models/product_model.dart';
import 'models/collection_model.dart';

class SeedingService {
  final DatabaseService _databaseService;

  SeedingService(this._databaseService);

  Future<void> seedDatabase() async {
    await _seedUsers();
    final addedProducts = await _seedProducts();

    // Seed collections
    await _databaseService.addCollection(
      Collection(
        id: '1',
        name: 'Fruit Basket',
        productIds: [addedProducts[0].id, addedProducts[1].id],
      ),
    );

    await _databaseService.addCollection(
      Collection(
        id: '2',
        name: 'Vegetable Garden',
        productIds: [addedProducts[2].id],
      ),
    );
  }

  Future<void> _seedUsers() async {
    final users = [
      User(id: '1', name: 'Alice', email: 'alice@example.com'),
      User(id: '2', name: 'Bob', email: 'bob@example.com'),
      User(id: '3', name: 'Charlie', email: 'charlie@example.com'),
      User(id: '4', name: 'Diana', email: 'diana@example.com'),
      User(id: '5', name: 'Eve', email: 'eve@example.com'),
    ];

    for (var user in users) {
      await _databaseService.addUser(user);
    }
  }

  Future<List<Product>> _seedProducts() async {
    final products = [
      Product(id: '1', name: 'Apple', description: 'A crisp and juicy apple.'),
      Product(id: '2', name: 'Banana', description: 'A ripe and sweet banana.'),
      Product(
        id: '3',
        name: 'Carrot',
        description: 'A crunchy and orange carrot.',
      ),
      Product(id: '4', name: 'Date', description: 'A sweet and chewy date.'),
      Product(
        id: '5',
        name: 'Eggplant',
        description: 'A fresh and purple eggplant.',
      ),
    ];

    final addedProducts = <Product>[];
    for (var product in products) {
      addedProducts.add(await _databaseService.addProduct(product));
    }
    return addedProducts;
  }
}
