import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/product_categories.dart';

/// Helper utilities for product-related operations
class ProductHelpers {
  const ProductHelpers._();

  /// Get icon for product category
  static IconData getCategoryIcon(String? category) {
    return ProductCategory.getIcon(category);
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
