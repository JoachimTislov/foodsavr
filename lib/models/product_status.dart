import 'package:flutter/material.dart';

/// Product status based on expiration date
enum ProductStatus {
  fresh,
  expiringSoon,
  expired;

  /// Get status color for the given color scheme
  Color getColor(ColorScheme colorScheme) {
    switch (this) {
      case ProductStatus.fresh:
        return colorScheme.primary;
      case ProductStatus.expiringSoon:
        return colorScheme.tertiary;
      case ProductStatus.expired:
        return colorScheme.error;
    }
  }

  /// Get status message
  String get message {
    switch (this) {
      case ProductStatus.fresh:
        return 'Fresh';
      case ProductStatus.expiringSoon:
        return 'Expires Soon';
      case ProductStatus.expired:
        return 'Expired';
    }
  }

  /// Get status icon
  IconData get icon {
    switch (this) {
      case ProductStatus.fresh:
        return Icons.check_circle_outline;
      case ProductStatus.expiringSoon:
        return Icons.warning_amber_rounded;
      case ProductStatus.expired:
        return Icons.error_outline;
    }
  }
}
