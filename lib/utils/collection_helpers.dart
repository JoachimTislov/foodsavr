import 'package:flutter/material.dart';
import '../models/collection_model.dart';

/// Helper utilities for collection-related operations
class CollectionHelpers {
  const CollectionHelpers._();

  /// Get icon for collection type
  static IconData getIcon(CollectionType type) {
    switch (type) {
      case CollectionType.inventory:
        return Icons.inventory_2;
      case CollectionType.shoppingList:
        return Icons.shopping_cart;
      case CollectionType.favorites:
        return Icons.favorite;
      case CollectionType.custom:
        return Icons.folder;
    }
  }

  /// Get color for collection type
  static Color getColor(CollectionType type, ColorScheme colorScheme) {
    switch (type) {
      case CollectionType.inventory:
        return colorScheme.primaryContainer;
      case CollectionType.shoppingList:
        return colorScheme.tertiaryContainer;
      case CollectionType.favorites:
        return colorScheme.errorContainer;
      case CollectionType.custom:
        return colorScheme.secondaryContainer;
    }
  }

  /// Get label for collection type
  static String getLabel(CollectionType type) {
    switch (type) {
      case CollectionType.inventory:
        return 'Inventory';
      case CollectionType.shoppingList:
        return 'Shopping';
      case CollectionType.favorites:
        return 'Favorites';
      case CollectionType.custom:
        return 'Custom';
    }
  }
}
