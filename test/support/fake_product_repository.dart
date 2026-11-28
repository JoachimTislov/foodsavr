import 'package:foodsavr/interfaces/i_product_repository.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';

/// In-memory repository that mirrors the Firestore repository id strategy:
/// an empty id is replaced with a generated one on [add].
class FakeProductRepository implements IProductRepository {
  final List<Product> products;
  final List<Product> added = [];
  final List<Product> updated = [];
  Object? addError;
  Object? getError;
  Object? updateError;
  Object? deleteError;
  Object? Function(String id)? getErrorForId;
  Object? Function(Product entity)? updateErrorForEntity;
  int _nextId = 1;

  FakeProductRepository([List<Product>? initial])
    : products = List.of(initial ?? const []);

  int get writes => added.length + updated.length;

  @override
  Future<Product> add(Product entity) async {
    if (addError != null) throw addError!;
    final saved = entity.id.isEmpty
        ? entity.copyWith(id: 'generated-${_nextId++}')
        : entity;
    products.add(saved);
    added.add(saved);
    return saved;
  }

  @override
  Future<void> update(Product entity) async {
    final error = updateErrorForEntity?.call(entity) ?? updateError;
    if (error != null) throw error;
    final index = products.indexWhere((p) => p.id == entity.id);
    if (index < 0) throw StateError('No document to update: ${entity.id}');
    products[index] = entity;
    updated.add(entity);
  }

  @override
  Future<Product?> get(String id) async {
    final error = getErrorForId?.call(id) ?? getError;
    if (error != null) throw error;
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<void> deleteCollection(Collection source, {String? destinationId}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) async {
    if (deleteError != null) throw deleteError!;
    products.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<Product>> getGlobalProducts() async =>
      products.where((p) => p.isGlobal).toList();

  @override
  Future<List<Product>> getPersonalProducts(String userId) async => products
      .where((p) => p.userId == userId && p.registryType == 'personal')
      .toList();

  @override
  Future<List<Product>> getProducts(String userId) async => products
      .where((p) => p.userId == userId && p.registryType != 'personal')
      .toList();
}
