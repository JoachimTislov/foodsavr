import 'package:flutter/material.dart';

/// Product category configuration
/// Add new categories here to ensure consistency across the app
class ProductCategory {
  final String name;
  final IconData icon;

  const ProductCategory({
    required this.name,
    required this.icon,
  });

  static const List<ProductCategory> all = [
    ProductCategory(name: 'Fruits', icon: Icons.apple),
    ProductCategory(name: 'Vegetables', icon: Icons.eco),
    ProductCategory(name: 'Dairy', icon: Icons.egg),
    ProductCategory(name: 'Bakery', icon: Icons.bakery_dining),
    ProductCategory(name: 'Pantry', icon: Icons.kitchen),
  ];

  /// Get icon for a category name
  static IconData getIcon(String? category) {
    if (category == null) return Icons.shopping_bag;

    final normalized = category.toLowerCase();
    for (final cat in all) {
      if (cat.name.toLowerCase() == normalized) {
        return cat.icon;
      }
    }
    return Icons.shopping_bag;
  }

  /// Get all category names
  static List<String> get allNames => all.map((c) => c.name).toList();
}
