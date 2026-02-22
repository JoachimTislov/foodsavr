import 'package:flutter/foundation.dart';

import '../models/product_model.dart';

/// Manages product selection and search filtering for the select-products screen.
class SelectProductsController extends ChangeNotifier {
  List<Product> _allProducts = [];
  String _query = '';
  final Set<int> _selectedIds = {};

  List<Product> get filteredProducts {
    if (_query.isEmpty) return List.unmodifiable(_allProducts);
    final lq = _query.toLowerCase();
    return _allProducts
        .where((p) => p.name.toLowerCase().contains(lq))
        .toList();
  }

  int get selectedCount => _selectedIds.length;

  bool isSelected(int productId) => _selectedIds.contains(productId);

  void loadProducts(List<Product> products) {
    _allProducts = List.of(products);
    notifyListeners();
  }

  void updateQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void toggleSelection(int productId) {
    if (_selectedIds.contains(productId)) {
      _selectedIds.remove(productId);
    } else {
      _selectedIds.add(productId);
    }
    notifyListeners();
  }
}
