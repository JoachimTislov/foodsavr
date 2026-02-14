import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Helper utilities for product-related operations
class ProductHelpers {
  const ProductHelpers._();

  /// Get icon for product category
  static IconData getCategoryIcon(String? category) {
    if (category == null) return Icons.shopping_bag;

    switch (category.toLowerCase()) {
      case 'fruits':
        return Icons.apple;
      case 'vegetables':
        return Icons.eco;
      case 'dairy':
        return Icons.egg;
      case 'bakery':
        return Icons.bakery_dining;
      case 'pantry':
        return Icons.kitchen;
      default:
        return Icons.shopping_bag;
    }
  }

  /// Format date with abbreviated month names (e.g., "Jan 15, 2024")
  /// Supports internationalization via intl package
  static String formatDateShort(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  /// Format date with full month names (e.g., "January 15, 2024")
  /// Supports internationalization via intl package
  static String formatDateFull(DateTime date) {
    return DateFormat.yMMMMd().format(date);
  }
}
