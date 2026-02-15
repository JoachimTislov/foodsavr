import 'package:flutter/material.dart';

/// Material 3 design system configuration and utilities
/// Provides helper methods for consistent Material 3 color usage
class Material3Config {
  const Material3Config._();

  /// Gets the appropriate "on" color for a given container color
  /// This ensures proper contrast for icons and text on container backgrounds
  static Color getOnContainerColor(BuildContext context, Color containerColor) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (containerColor) {
      case final color when color == colorScheme.primaryContainer:
        return colorScheme.onPrimaryContainer;
      case final color when color == colorScheme.secondaryContainer:
        return colorScheme.onSecondaryContainer;
      case final color when color == colorScheme.tertiaryContainer:
        return colorScheme.onTertiaryContainer;
      case final color when color == colorScheme.errorContainer:
        return colorScheme.onErrorContainer;
      default:
        return colorScheme.onPrimaryContainer;
    }
  }

  /// Standard elevation values for Material 3
  static const double elevationLevel0 = 0.0;
  static const double elevationLevel1 = 1.0;
  static const double elevationLevel2 = 3.0;
  static const double elevationLevel3 = 6.0;
  static const double elevationLevel4 = 8.0;
  static const double elevationLevel5 = 12.0;

  /// Standard spacing values
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  /// Standard border radius values
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusExtraLarge = 28.0;
}
