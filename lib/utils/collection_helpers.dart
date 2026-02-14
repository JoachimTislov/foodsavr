import 'package:flutter/material.dart';
import '../models/collection_model.dart';
import '../constants/collection_config.dart';

/// Helper utilities for collection-related operations
class CollectionHelpers {
  const CollectionHelpers._();

  /// Get icon for collection type
  static IconData getIcon(CollectionType type) {
    return CollectionConfig.getIcon(type);
  }

  /// Get color for collection type
  static Color getColor(CollectionType type, ColorScheme colorScheme) {
    return CollectionConfig.getColor(type, colorScheme);
  }

  /// Get label for collection type
  static String getLabel(CollectionType type) {
    return CollectionConfig.getLabel(type);
  }
}
