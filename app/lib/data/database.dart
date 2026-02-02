import '../authentication/domain/user.dart';
import 'models/collection_model.dart';
import 'models/product_model.dart';

class DatabaseService {
  final List<User> _users = [];
  final List<Product> _products = [];
  final List<Collection> _collections = [];

  // User methods
  Future<User> addUser(User user) async {
    _users.add(user);
    return user;
  }

  Future<User?> getUser(String id) async {
    return _users.firstWhere((user) => user.id == id);
  }

  Future<void> updateUser(User user) async {
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
    }
  }

  Future<void> deleteUser(String id) async {
    _users.removeWhere((user) => user.id == id);
  }

  // Product methods
  Future<Product> addProduct(Product product) async {
    _products.add(product);
    return product;
  }

  Future<Product?> getProduct(String id) async {
    return _products.firstWhere((product) => product.id == id);
  }

  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
    }
  }

  Future<void> deleteProduct(String id) async {
    _products.removeWhere((product) => product.id == id);
  }

  // Collection methods
  Future<Collection> addCollection(Collection collection) async {
    _collections.add(collection);
    return collection;
  }

  Future<Collection?> getCollection(String id) async {
    return _collections.firstWhere((collection) => collection.id == id);
  }

  Future<void> updateCollection(Collection collection) async {
    final index = _collections.indexWhere((c) => c.id == collection.id);
    if (index != -1) {
      _collections[index] = collection;
    }
  }

  Future<void> deleteCollection(String id) async {
    _collections.removeWhere((collection) => collection.id == id);
  }
}
