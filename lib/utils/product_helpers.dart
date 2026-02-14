import 'package:flutter/material.dart';

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

  /// Format date with abbreviated month names
  static String formatDateShort(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Format date with full month names
  static String formatDateFull(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
