import 'package:flutter/material.dart';

/// Utility class for product view mode icons
class ViewModeHelper {
  const ViewModeHelper._();

  /// Get the icon for a specific product view mode
  static IconData getViewModeIcon(ProductViewMode mode) {
    switch (mode) {
      case ProductViewMode.compact:
        return Icons.view_headline;
      case ProductViewMode.normal:
        return Icons.view_agenda;
      case ProductViewMode.details:
        return Icons.view_day;
    }
  }
}

/// Product view mode enumeration
enum ProductViewMode { compact, normal, details }
