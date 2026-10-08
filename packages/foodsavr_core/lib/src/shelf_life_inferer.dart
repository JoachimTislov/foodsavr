/// Infers a default shelf life (days) from a product category.
class ShelfLifeInferer {
  ShelfLifeInferer({
    Map<String, int>? categoryDays,
    Map<String, int> overrides = const {},
  }) : _overrides = overrides,
       _categoryDays = categoryDays ?? _defaults;

  static const _defaults = <String, int>{
    'dairy': 7,
    'meat': 4,
    'fish': 2,
    'produce': 5,
    'bakery': 3,
    'pantry': 180,
    'frozen': 180,
    'beverages': 365,
    'snacks': 90,
  };

  final Map<String, int> _categoryDays;
  final Map<String, int> _overrides;

  /// Days before expiry for a category; per-product [overrides] win,
  /// then category table, then [fallbackDays].
  int inferDays({
    required String category,
    String? productId,
    int fallbackDays = 14,
  }) {
    if (productId != null && _overrides.containsKey(productId)) {
      return _overrides[productId]!;
    }
    final key = category.toLowerCase();
    if (_categoryDays.containsKey(key)) return _categoryDays[key]!;
    return fallbackDays;
  }
}
