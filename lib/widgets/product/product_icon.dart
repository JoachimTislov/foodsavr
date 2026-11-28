import 'package:flutter/material.dart';

import '../../constants/product_categories.dart';
import '../../models/product_model.dart';

/// Expressive, image-free visual badge for any grocery product.
///
/// Matches common English and Norwegian grocery keywords in [name] to crisp
/// Material icons inside a category-tinted rounded badge, falling back to
/// [ProductCategory.getIcon]. Wrapped in [ExcludeSemantics] so decorative icons
/// do not clutter screen readers.
class ProductIcon extends StatelessWidget {
  final String name;
  final String? category;
  final double size;
  final double? iconSize;
  final BorderRadius? borderRadius;

  const ProductIcon({
    super.key,
    required this.name,
    this.category,
    this.size = 40,
    this.iconSize,
    this.borderRadius,
  });

  ProductIcon.fromProduct(
    Product product, {
    super.key,
    this.size = 40,
    this.iconSize,
    this.borderRadius,
  }) : name = product.name,
       category = product.category;

  static final List<(RegExp, IconData)> _keywordIcons = [
    // Specific multi-word items before general keywords.
    (
      RegExp(
        r'(tomato\s*sauce|tomatsaus|pasta\s*sauce|pastasaus|soup|suppe|stew|gryte|broth|buljong|sauce|saus|curry|karri|pesto|salsa|canned\s+tomato|hermetisk[a-zæøå]*\s+tomat|hakkede\s+tomat)',
        unicode: true,
      ),
      Icons.soup_kitchen,
    ),
    (RegExp(r'(eggplant|aubergine)', unicode: true), Icons.eco),
    (RegExp(r'(ice\s*cream|iskrem)', unicode: true), Icons.icecream),
    (
      RegExp(r'(coffee|kaffe|espresso|latte|cappuccino)', unicode: true),
      Icons.coffee,
    ),
    (
      RegExp(r'(\btea\b|\bte\b|chai|matcha)', unicode: true),
      Icons.emoji_food_beverage,
    ),
    (RegExp(r'(\bwine\b|\bvin\b)', unicode: true), Icons.wine_bar),
    (RegExp(r'(beer|\bøl\b|cider|sider)', unicode: true), Icons.sports_bar),
    (
      RegExp(r'(\bwater\b|\bvann\b|farris|sparkling)', unicode: true),
      Icons.water_drop,
    ),
    (
      RegExp(
        r'(milk|melk|mjølk|oat\s*drink|havredrikk|juice|\bjus\b|\bsaft\b|smoothie|soda|brus|cola|lemonade|kefir|biola|fløte|cream)',
        unicode: true,
      ),
      Icons.local_drink,
    ),
    (RegExp(r'(yogh?urt|skyr|kvarg|rømme)', unicode: true), Icons.icecream),
    (RegExp(r'(\beggs?\b)', unicode: true), Icons.egg),
    (
      RegExp(r'(butter|smør|margarin[a-zæøå]*|bremykt|toast)', unicode: true),
      Icons.breakfast_dining,
    ),
    (
      RegExp(
        r'(cheese|\bost\b|gulost|brunost|hvitost|kvitost|kremost|smøreost|norvegia|jarlsberg|cheddar|mozzarella|parmesan|\bfeta\b|\bbrie\b|cottage)',
        unicode: true,
      ),
      Icons.tapas,
    ),
    (RegExp(r'pizza', unicode: true), Icons.local_pizza),
    (
      RegExp(
        r'(\bcake\b|\bkake\b|muffin|cupcake|brownie|pastry|bakst)',
        unicode: true,
      ),
      Icons.cake,
    ),
    (
      RegExp(
        r'(cookie|kjeks|biscuit|cracker|crispbread|knekkebrød|chocolate|sjokolade|chips|popcorn|snack)',
        unicode: true,
      ),
      Icons.cookie,
    ),
    (
      RegExp(
        r'(bread|brød|\bloaf\b|\bloff\b|baguette|croissant|tortilla|lefse|lompe|\bpita\b|\bwrap\b|bagel|\bbuns?\b|bolle[rn]?|rundstykke[a-zæøå]*|scone|waffle|vaffel|ciabatta|focaccia|brioche|sourdough|surdeig)',
        unicode: true,
      ),
      Icons.bakery_dining,
    ),
    (
      RegExp(
        r'(pasta|spaghetti|macaroni|makaroni|noodle|nudler|ramen|lasagne|penne|fusilli)',
        unicode: true,
      ),
      Icons.ramen_dining,
    ),
    (
      RegExp(
        r'(\brice\b|\bris\b|quinoa|couscous|bulgur|risotto)',
        unicode: true,
      ),
      Icons.rice_bowl,
    ),
    (
      RegExp(
        r'(flour|\bmel\b|hvetemel|rugmel|speltmel|\boats?\b|havre[a-zæøå]*|sugar|sukker|cereal|m[üu]sli|granola|beans?|bønne[a-zæøå]*|lentil|linse[a-zæøå]*|chickpea|kikert[a-zæøå]*|\bnuts?\b|nøtt[a-zæøå]*|almond|mandel|\bsalt\b|spice|krydder)',
        unicode: true,
      ),
      Icons.grain,
    ),
    (
      RegExp(
        r'(\boil\b|olje\b|vinegar|eddik|honey|honning|syrup|sirup|ketchup|mustard|sennep|mayo|majones|\bsoy\b|soya|syltetøy|\bjam\b)',
        unicode: true,
      ),
      Icons.opacity,
    ),
    (
      RegExp(
        r'(fish|fisk|salmon|laks|\bcod\b|torsk|tuna|tunfisk|mackerel|makrell|shrimp|reke|sardine|herring|sild)',
        unicode: true,
      ),
      Icons.set_meal,
    ),
    (
      RegExp(
        r'(meat|kjøtt[a-zæøå]*|beef|storfe|pork|svin|chicken|kylling|turkey|kalkun|lamb|\blam\b|bacon|\bham\b|skinke|sausage|pølse[a-zæøå]*|salami)',
        unicode: true,
      ),
      Icons.kebab_dining,
    ),
    (
      RegExp(
        r'(apple|eple[rn]?|\bpears?\b|pære[rn]?|peach|fersken|plum|plomme[a-zæøå]*)',
        unicode: true,
      ),
      Icons.apple,
    ),
    (
      RegExp(
        r'(orange|appelsin[a-zæøå]*|clementine|klementin[a-zæøå]*|mandarin[a-zæøå]*|lemon|sitron[a-zæøå]*|\blime\b|grapefruit|grapefrukt|citrus|sitrus)',
        unicode: true,
      ),
      Icons.sunny,
    ),
    (
      RegExp(
        r'(banana|banan[a-zæøå]*|berr(?:y|ies)|bær\b|cherr(?:y|ies)|morell[a-zæøå]*|grape|drue[rn]?|mango|pineapple|ananas|melon|kiwi|avocado|avokado)',
        unicode: true,
      ),
      Icons.spa,
    ),
    (
      RegExp(
        r'(salad|salat|lettuce|spinach|spinat|\bkale\b|cucumber|agurk|broccoli|brokkoli|cauliflower|cabbage|kål\b|celery|selleri|leek|purre|\bpeas?\b|\berter?\b|\bherbs?\b|\burter?\b|basil[a-zæøå]*|coriander|koriander|parsley|persille|ruccola|arugula)',
        unicode: true,
      ),
      Icons.eco,
    ),
    (
      RegExp(
        r'(carrot|gulrot|gulrøtter|potato[a-z]*|potet[a-zæøå]*|onion|løk\b|garlic|tomato[a-z]*|tomat[a-zæøå]*|paprika|bell\s*pepper|\bcorn\b|\bmais\b|mushroom|\bsopp\b|zucchini|squash|radish|reddik|\bbeets?\b|rødbet[a-zæøå]*|ginger|ingefær)',
        unicode: true,
      ),
      Icons.grass,
    ),
    (RegExp(r'(frozen|frossen|frosne|fryst)', unicode: true), Icons.ac_unit),
  ];

  /// Resolves the most expressive Material icon for a product [name] and
  /// optional [category], falling back to [ProductCategory.getIcon].
  static IconData resolveIcon(String name, {String? category}) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      for (final (pattern, icon) in _keywordIcons) {
        if (pattern.hasMatch(normalized)) return icon;
      }
    }
    return ProductCategory.getIcon(category);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveCategory =
        ProductCategory.normalize(category) ??
        ProductCategory.inferFromName(name);
    final colors = ProductCategory.badgeColors(effectiveCategory, colorScheme);
    final resolvedIconSize = iconSize ?? (size * 0.54).clamp(16.0, 36.0);
    final resolvedRadius =
        borderRadius ?? BorderRadius.circular((size * 0.25).clamp(8.0, 14.0));

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: resolvedRadius,
        ),
        alignment: Alignment.center,
        child: Icon(
          resolveIcon(name, category: effectiveCategory),
          size: resolvedIconSize,
          color: colors.foreground,
        ),
      ),
    );
  }
}
