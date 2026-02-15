import 'package:flutter/material.dart';
import '../utils/collection_types.dart';

/// Collection type configuration
/// Only inventory and shopping list are supported
class CollectionConfig {
  final CollectionType type;
  final String label;
  final IconData icon;
  final Color Function(ColorScheme) colorGetter;

  const CollectionConfig({
    required this.type,
    required this.label,
    required this.icon,
    required this.colorGetter,
  });

  static final List<CollectionConfig> all = [
    CollectionConfig(
      type: CollectionType.inventory,
      label: 'Inventory',
      icon: Icons.inventory_2,
      colorGetter: (cs) => cs.primaryContainer,
    ),
    CollectionConfig(
      type: CollectionType.shoppingList,
      label: 'Shopping',
      icon: Icons.shopping_cart,
      colorGetter: (cs) => cs.tertiaryContainer,
    ),
  ];

  /// Get configuration for a collection type
  static CollectionConfig? getConfig(CollectionType type) {
    try {
      return all.firstWhere((config) => config.type == type);
    } catch (e) {
      return null;
    }
  }

  /// Get icon for collection type
  static IconData getIcon(CollectionType type) {
    return getConfig(type)?.icon ?? Icons.folder;
  }

  /// Get label for collection type
  static String getLabel(CollectionType type) {
    return getConfig(type)?.label ?? 'Unknown';
  }

  /// Get color for collection type
  static Color getColor(CollectionType type, ColorScheme colorScheme) {
    final config = getConfig(type);
    return config?.colorGetter(colorScheme) ?? colorScheme.surfaceContainerHighest;
  }
}
