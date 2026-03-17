import 'package:flutter/foundation.dart';

import '../models/product_model.dart';

/// Manages product selection and search filtering for the select-products screen.
class SelectProductsController extends ChangeNotifier {
  List<Product> _allProducts = [];
  String _query = '';
  final Set<int> _selectedIds = {};
  bool _isLoading = false;

  List<Product> get filteredProducts {
    if (_query.isEmpty) return List.unmodifiable(_allProducts);
    final lq = _query.toLowerCase();
    return _allProducts
        .where((p) => p.name.toLowerCase().contains(lq))
        .toList();
  }

  int get selectedCount => _selectedIds.length;
  bool get isLoading => _isLoading;
  Set<int> get selectedIds => _selectedIds;

  List<Product> get selectedProducts {
    return _allProducts.where((p) => _selectedIds.contains(p.id)).toList();
  }

  bool isSelected(int productId) => _selectedIds.contains(productId);

  void setAvailableProducts(List<Product> products) {
    _allProducts = List.of(products);
    _isLoading = false;
    notifyListeners();
  }

  void loadProducts(List<Product> products) {
    setAvailableProducts(products);
  }

  void setSearchQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void updateQuery(String query) {
    setSearchQuery(query);
  }

  void toggleSelection(int productId) {
    if (_selectedIds.contains(productId)) {
      _selectedIds.remove(productId);
    } else {
      _selectedIds.add(productId);
    }
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
