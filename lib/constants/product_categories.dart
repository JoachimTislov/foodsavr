import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Product category configuration.
///
/// Products store the stable [key]; [label] localizes it for display. Add new
/// categories here and to `product.categories` in every locale file.
class ProductCategory {
  final String key;
  final IconData icon;

  const ProductCategory({required this.key, required this.icon});

  static const List<ProductCategory> all = [
    ProductCategory(key: 'fruits', icon: Icons.apple),
    ProductCategory(key: 'vegetables', icon: Icons.eco),
    ProductCategory(key: 'dairy', icon: Icons.egg),
    ProductCategory(key: 'bakery', icon: Icons.bakery_dining),
    ProductCategory(key: 'pantry', icon: Icons.kitchen),
  ];

  /// All category keys, in display order.
  static List<String> get allKeys => all.map((c) => c.key).toList();

  static ProductCategory? _find(String? category) {
    if (category == null) return null;
    final normalized = category.trim().toLowerCase();
    for (final cat in all) {
      if (cat.key == normalized) return cat;
    }
    return null;
  }

  /// Maps a stored category to its stable key.
  ///
  /// Legacy English names (`Dairy`) become keys (`dairy`), empty values become
  /// null, and unknown values pass through so free-form categories survive.
  static String? normalize(Object? category) {
    if (category is! String || category.trim().isEmpty) return null;
    return _find(category)?.key ?? category;
  }

  /// Get icon for a category key or legacy name.
  static IconData getIcon(String? category) =>
      _find(category)?.icon ?? Icons.shopping_bag;

  /// Localized display name for a category key; unknown values are shown
  /// as stored.
  static String label(String category) {
    return switch (_find(category)?.key) {
      'fruits' => 'product.categories.fruits'.tr(),
      'vegetables' => 'product.categories.vegetables'.tr(),
      'dairy' => 'product.categories.dairy'.tr(),
      'bakery' => 'product.categories.bakery'.tr(),
      'pantry' => 'product.categories.pantry'.tr(),
      _ => category,
    };
  }
}
