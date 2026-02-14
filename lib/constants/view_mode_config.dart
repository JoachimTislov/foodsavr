import '../utils/view_mode_helper.dart';

/// Configuration for product view modes
class ProductViewConfig {
  final ProductViewMode mode;
  final double cardSpacing;
  final double horizontalPadding;

  const ProductViewConfig({
    required this.mode,
    required this.cardSpacing,
    required this.horizontalPadding,
  });

  static const compact = ProductViewConfig(
    mode: ProductViewMode.compact,
    cardSpacing: 2,
    horizontalPadding: 12,
  );

  static const normal = ProductViewConfig(
    mode: ProductViewMode.normal,
    cardSpacing: 6,
    horizontalPadding: 16,
  );

  static const details = ProductViewConfig(
    mode: ProductViewMode.details,
    cardSpacing: 8,
    horizontalPadding: 16,
  );

  /// Get configuration for a view mode
  static ProductViewConfig getConfig(ProductViewMode mode) {
    switch (mode) {
      case ProductViewMode.compact:
        return compact;
      case ProductViewMode.normal:
        return normal;
      case ProductViewMode.details:
        return details;
    }
  }
}
