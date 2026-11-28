import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Product category configuration.
///
/// Products store the stable [key]; [label] localizes it for display. Add new
/// categories here and to `product.categories` in every locale file.
class ProductCategory {
  final String key;
  final IconData icon;
  final Color seedColor;

  const ProductCategory({
    required this.key,
    required this.icon,
    this.seedColor = const Color(0xFF4E6B50),
  });

  static const List<ProductCategory> all = [
    ProductCategory(
      key: 'fruits',
      icon: Icons.apple,
      seedColor: Color(0xFFC94A38),
    ),
    ProductCategory(
      key: 'vegetables',
      icon: Icons.eco,
      seedColor: Color(0xFF2E7D4F),
    ),
    ProductCategory(
      key: 'dairy',
      icon: Icons.egg,
      seedColor: Color(0xFF2A6FA8),
    ),
    ProductCategory(
      key: 'bakery',
      icon: Icons.bakery_dining,
      seedColor: Color(0xFFB8701B),
    ),
    ProductCategory(
      key: 'pantry',
      icon: Icons.kitchen,
      seedColor: Color(0xFF6E579B),
    ),
  ];

  /// All category keys, in display order.
  static List<String> get allKeys => all.map((c) => c.key).toList();

  static ProductCategory? _find(String? category) {
    if (category == null) return null;
    final normalized = category.trim().toLowerCase();
    for (final cat in all) {
      if (cat.key == normalized) return cat;
    }
    return null;
  }

  /// Maps a stored category to its stable key.
  ///
  /// Legacy English names (`Dairy`) become keys (`dairy`), empty values become
  /// null, and unknown values pass through so free-form categories survive.
  static String? normalize(Object? category) {
    if (category is! String || category.trim().isEmpty) return null;
    return _find(category)?.key ?? category;
  }

  /// Get icon for a category key or legacy name.
  static IconData getIcon(String? category) =>
      _find(category)?.icon ?? Icons.shopping_bag;

  /// Harmonious background and foreground badge colors for [category] in both
  /// light and dark themes.
  static ({Color background, Color foreground}) badgeColors(
    String? category,
    ColorScheme colorScheme,
  ) {
    final cat = _find(category);
    if (cat == null) {
      return (
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    }
    if (colorScheme.brightness == Brightness.dark) {
      return (
        background: Color.alphaBlend(
          cat.seedColor.withValues(alpha: 0.24),
          colorScheme.surfaceContainerHighest,
        ),
        foreground: Color.alphaBlend(
          Colors.white.withValues(alpha: 0.45),
          cat.seedColor,
        ),
      );
    }
    return (
      background: Color.alphaBlend(
        cat.seedColor.withValues(alpha: 0.14),
        colorScheme.surface,
      ),
      foreground: Color.alphaBlend(
        colorScheme.onSurface.withValues(alpha: 0.28),
        cat.seedColor,
      ),
    );
  }

  static final List<(RegExp, String)> _nameCategoryRules = [
    // Specific multi-word and disambiguation rules first.
    (
      RegExp(
        r'(tomato\s*sauce|tomatsaus|pasta\s*sauce|pastasaus|canned\s+tomato|hermetisk\w*\s+tomat|hakkede\s+tomat|tomato\s*paste|tomatpur[eé]|ketchup|peanut\s*butter|peanøttsmør|coconut\s*milk|kokosmelk|apple\s*juice|eplejuice|orange\s*juice|appelsinjuice|\bjuice\b|\bjus\b|\bsaft\b|smoothie|syltetøy|\bjam\b|marmelade|marmalade|olive\s*oil|olivenolje|rapsolje|matolje)',
        unicode: true,
      ),
      'pantry',
    ),
    (RegExp(r'(eggplant|aubergine|butternut)', unicode: true), 'vegetables'),
    (
      RegExp(
        r'(oat\s*milk|oat\s*drink|havremelk|havredrikk|soy\s*milk|soyamelk|soyamjølk|almond\s*milk|mandelmelk|ice\s*cream|iskrem|sour\s*cream)',
        unicode: true,
      ),
      'dairy',
    ),
    // Dairy & eggs (EN + NB).
    (
      RegExp(
        r'(milk|melk|mjølk|cheese|\bost\b|gulost|brunost|hvitost|kvitost|kremost|smøreost|blåmuggost|geitost|norvegia|jarlsberg|cheddar|mozzarella|parmesan|\bfeta\b|\bbrie\b|cottage|\beggs?\b|yogh?urt|skyr|kvarg|butter|smør|margarin[a-zæøå]*|bremykt|cream|fløte|rømme|kefir|biola|cultura)',
        unicode: true,
      ),
      'dairy',
    ),
    // Bakery (EN + NB).
    (
      RegExp(
        r'(bread|brød|crispbread|knekkebrød|\bloaf\b|\bloff\b|toast|baguette|croissant|tortilla|lefse|lompe|\bpita\b|\bwrap\b|bagel|\bbuns?\b|bolle[rn]?|rundstykke[a-zæøå]*|\bcake\b|\bkake\b|muffin|scone|pastry|bakst|cookie|kjeks|biscuit|cracker|waffle|vaffel|pancake|pannekake|ciabatta|focaccia|brioche|sourdough|surdeig)',
        unicode: true,
      ),
      'bakery',
    ),
    // Fruits (EN + NB).
    (
      RegExp(
        r'(apple|eple[rn]?|banana|banan[a-zæøå]*|orange|appelsin[a-zæøå]*|clementine|klementin[a-zæøå]*|mandarin[a-zæøå]*|lemon|sitron[a-zæøå]*|\blime\b|grapefruit|grapefrukt|\bpears?\b|pære[rn]?|peach|fersken|nectarine|nektarin|plum|plomme[a-zæøå]*|grape|drue[rn]?|berr(?:y|ies)|bær\b|cherr(?:y|ies)|morell[a-zæøå]*|mango|pineapple|ananas|melon|kiwi|avocado|avokado|pomegranate|granateple|\bfigs?\b|fiken|papaya|apricot|aprikos|fruit|frukt)',
        unicode: true,
      ),
      'fruits',
    ),
    // Vegetables (EN + NB).
    (
      RegExp(
        r'(tomato[a-z]*|tomat[a-zæøå]*|carrot|gulrot|gulrøtter|potato[a-z]*|potet[a-zæøå]*|onion|løk\b|garlic|salad|salat|lettuce|spinach|spinat|\bkale\b|cucumber|agurk|bell\s*pepper|paprika|broccoli|brokkoli|cauliflower|cabbage|kål\b|celery|selleri|leek|purre|\bpeas?\b|\berter?\b|\bcorn\b|\bmais\b|mushroom|\bsopp\b|sjampinjong|zucchini|squash|radish|reddik|\bbeets?\b|rødbet[a-zæøå]*|asparagus|asparges|ginger|ingefær|chili|\bherbs?\b|\burter?\b|basil[a-zæøå]*|coriander|koriander|parsley|persille|\bdill\b|chive|ruccola|arugula|vegetable|grønnsak[a-zæøå]*|turnip|parsnip|pastinakk)',
        unicode: true,
      ),
      'vegetables',
    ),
    // Pantry, grains, drinks, canned goods & proteins (EN + NB).
    (
      RegExp(
        r'(coffee|kaffe|espresso|\btea\b|\bte\b|pasta|spaghetti|macaroni|makaroni|noodle|nudler|ramen|lasagne|\brice\b|\bris\b|flour|\bmel\b|hvetemel|rugmel|speltmel|sammalt|sugar|sukker|\boats?\b|havre[a-zæøå]*|\boil\b|olje\b|vinegar|eddik|soup|suppe|sauce|saus|\bwater\b|\bvann\b|farris|soda|brus|cola|beer|\bøl\b|\bwine\b|\bvin\b|honey|honning|syrup|sirup|beans?|bønne[a-zæøå]*|lentil|linse[a-zæøå]*|chickpea|kikert[a-zæøå]*|mackerel|makrell|tuna|tunfisk|salmon|laks|fish|fisk|\bcod\b|torsk|chicken|kylling|beef|storfe|pork|svin|meat|kjøtt[a-zæøå]*|bacon|\bham\b|skinke|sausage|pølse[a-zæøå]*|\bsalt\b|spice|krydder|cereal|m[üu]sli|granola|quinoa|couscous|\bnuts?\b|nøtt[a-zæøå]*|almond|mandel|chocolate|sjokolade|cocoa|kakao|pesto|salsa|mustard|sennep|mayo|majones|\bsoy\b|soya|broth|buljong|canned|hermetisk|pizza|taco|chips|popcorn|raisin|rosin)',
        unicode: true,
      ),
      'pantry',
    ),
  ];

  /// Infers one of the five [ProductCategory] keys from a product [name]
  /// (English or Norwegian, case-insensitive), or returns `null` if unknown.
  static String? inferFromName(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final (pattern, categoryKey) in _nameCategoryRules) {
      if (pattern.hasMatch(normalized)) return categoryKey;
    }
    return null;
  }

  /// Localized display name for a category key; unknown values are shown
  /// as stored.
  static String label(String category) {
    return switch (_find(category)?.key) {
      'fruits' => 'product.categories.fruits'.tr(),
      'vegetables' => 'product.categories.vegetables'.tr(),
      'dairy' => 'product.categories.dairy'.tr(),
      'bakery' => 'product.categories.bakery'.tr(),
      'pantry' => 'product.categories.pantry'.tr(),
      _ => category,
    };
  }
}
