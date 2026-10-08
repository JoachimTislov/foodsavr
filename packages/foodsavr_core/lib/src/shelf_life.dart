import 'line_item.dart';

/// Category labels used for shelf-life defaults. Intentionally coarse:
/// enough to pick a sane default, overridable per product downstream.
enum FoodCategory {
  dairy,
  meat,
  fish,
  produce,
  bakery,
  pantry,
  frozen,
  beverages,
  other,
}

/// Infers a default shelf life (in days) from category-based defaults.
///
/// Users can always override the result per item in the app; this exists so
/// ingestion can propose sensible expiry dates for items that arrive without
/// one (receipts, loyalty imports).
class ShelfLifeInferer {
  ShelfLifeInferer({Map<FoodCategory, int> defaults = defaultDays})
    : _defaults = Map.of(defaults);

  static const Map<FoodCategory, int> defaultDays = {
    FoodCategory.dairy: 7,
    FoodCategory.meat: 3,
    FoodCategory.fish: 2,
    FoodCategory.produce: 5,
    FoodCategory.bakery: 4,
    FoodCategory.pantry: 180,
    FoodCategory.frozen: 180,
    FoodCategory.beverages: 365,
    FoodCategory.other: 14,
  };

  static const Map<String, FoodCategory> _keywordCategories = {
    'milk': FoodCategory.dairy,
    'melk': FoodCategory.dairy,
    'yogurt': FoodCategory.dairy,
    'yoghurt': FoodCategory.dairy,
    'cheese': FoodCategory.dairy,
    'ost': FoodCategory.dairy,
    'butter': FoodCategory.dairy,
    'smør': FoodCategory.dairy,
    'cream': FoodCategory.dairy,
    'chicken': FoodCategory.meat,
    'kylling': FoodCategory.meat,
    'beef': FoodCategory.meat,
    'okse': FoodCategory.meat,
    'pork': FoodCategory.meat,
    'svin': FoodCategory.meat,
    'mince': FoodCategory.meat,
    'kjøtt': FoodCategory.meat,
    'salmon': FoodCategory.fish,
    'laks': FoodCategory.fish,
    'fish': FoodCategory.fish,
    'fisk': FoodCategory.fish,
    'torsk': FoodCategory.fish,
    'apple': FoodCategory.produce,
    'eple': FoodCategory.produce,
    'banana': FoodCategory.produce,
    'banan': FoodCategory.produce,
    'tomato': FoodCategory.produce,
    'tomat': FoodCategory.produce,
    'salad': FoodCategory.produce,
    'salat': FoodCategory.produce,
    'carrot': FoodCategory.produce,
    'gulrot': FoodCategory.produce,
    'onion': FoodCategory.produce,
    'løk': FoodCategory.produce,
    'potato': FoodCategory.produce,
    'potet': FoodCategory.produce,
    'vegetable': FoodCategory.produce,
    'grønt': FoodCategory.produce,
    'fruit': FoodCategory.produce,
    'frukt': FoodCategory.produce,
    'bread': FoodCategory.bakery,
    'brød': FoodCategory.bakery,
    'baguette': FoodCategory.bakery,
    'bun': FoodCategory.bakery,
    'bolle': FoodCategory.bakery,
    'pasta': FoodCategory.pantry,
    'rice': FoodCategory.pantry,
    'ris': FoodCategory.pantry,
    'flour': FoodCategory.pantry,
    'mel': FoodCategory.pantry,
    'sugar': FoodCategory.pantry,
    'sukker': FoodCategory.pantry,
    'cereal': FoodCategory.pantry,
    'kornblanding': FoodCategory.pantry,
    'beans': FoodCategory.pantry,
    'bønner': FoodCategory.pantry,
    'canned': FoodCategory.pantry,
    'hermetikk': FoodCategory.pantry,
    'oil': FoodCategory.pantry,
    'olje': FoodCategory.pantry,
    'frozen': FoodCategory.frozen,
    'frossen': FoodCategory.frozen,
    'is': FoodCategory.frozen,
    'ice': FoodCategory.frozen,
    'juice': FoodCategory.beverages,
    'saft': FoodCategory.beverages,
    'soda': FoodCategory.beverages,
    'brus': FoodCategory.beverages,
    'water': FoodCategory.beverages,
    'vann': FoodCategory.beverages,
    'coffee': FoodCategory.beverages,
    'kaffe': FoodCategory.beverages,
    'tea': FoodCategory.beverages,
    'te': FoodCategory.beverages,
  };

  final Map<FoodCategory, int> _defaults;

  /// Days of default shelf life for [category], null when unknown.
  int? defaultFor(FoodCategory category) => _defaults[category];

  /// Infers shelf life for a [LineItem] from its normalized name.
  /// Returns the category default in days, or null if no category matches.
  int? infer(LineItem item) {
    final category = categorize(item.normalizedName);
    return category == null ? null : defaultFor(category);
  }

  /// First matching category for a (normalized, lowercase) [name].
  FoodCategory? categorize(String name) {
    for (final e in _keywordCategories.entries) {
      if (name.contains(e.key)) return e.value;
    }
    return null;
  }
}
