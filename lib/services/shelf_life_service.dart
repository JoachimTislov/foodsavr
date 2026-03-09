import 'package:injectable/injectable.dart';
import '../models/product_model.dart';

@lazySingleton
class ShelfLifeService {
  // Common Durations
  static const _twoDays = Duration(days: 2);
  static const _threeDays = Duration(days: 3);
  static const _fourDays = Duration(days: 4);
  static const _fiveDays = Duration(days: 5);
  static const _sevenDays = Duration(days: 7);
  static const _tenDays = Duration(days: 10);
  static const _fourteenDays = Duration(days: 14);
  static const _twentyEightDays = Duration(days: 28);
  static const _thirtyDays = Duration(days: 30);
  static const _ninetyDays = Duration(days: 90);
  static const _sixMonths = Duration(days: 180);
  static const _oneYear = Duration(days: 365);
  static const _twoYears = Duration(days: 730);

  /// A heuristic mapping of Open Food Facts category tags to a default shelf life duration.
  /// This serves as the "Smart Default" layer for zero-interaction expiration estimation.
  final Map<String, Duration> _categoryDurations = {
    // Dairy & Eggs
    'en:milks': _tenDays,
    'en:yogurts': _fourteenDays,
    'en:cheeses': _thirtyDays,
    'en:eggs': _twentyEightDays,
    'en:butter': _ninetyDays,

    // Meats & Fish
    'en:fresh-meats': _fourDays,
    'en:poultries': _fourDays,
    'en:fishes': _twoDays,
    'en:seafood': _twoDays,
    'en:processed-meats': _fourteenDays, // e.g., sausages, ham
    // Bakery
    'en:breads': _fiveDays,
    'en:pastries': _threeDays,

    // Produce
    'en:fresh-fruits': _sevenDays,
    'en:fresh-vegetables': _sevenDays,
    'en:salads': _fiveDays,

    // Pantry / Long-term
    'en:canned-foods': _twoYears,
    'en:dried-products': _oneYear,
    'en:pastas': _twoYears,
    'en:rice': _twoYears,
    'en:cereals': _oneYear,
    'en:condiments': _sixMonths,
    'en:sauces': _oneYear,
    'en:snacks': _sixMonths,
    'en:beverages': _oneYear,

    // Frozen
    'en:frozen-foods': _sixMonths,
    'en:ice-creams': _sixMonths,
  };

  /// Estimates the expiration date for a product based on its tags/categories.
  /// If no match is found, returns null, meaning no smart default could be applied.
  DateTime? estimateExpiration(Product product, {DateTime? addedDate}) {
    final baseDate = addedDate ?? DateTime.now();

    // Iterate through the product's tags to find a matching category duration
    for (final tag in product.tags) {
      final normalizedTag = tag.toLowerCase().trim();
      if (_categoryDurations.containsKey(normalizedTag)) {
        return baseDate.add(_categoryDurations[normalizedTag]!);
      }
    }

    // Fallback: If we have a general 'category' string, try to match it
    if (product.category != null) {
      final cat = product.category!.toLowerCase();
      const fallbackMapping = {
        'en:milks': ['dairy', 'milk'],
        'en:fresh-meats': ['meat'],
        'en:poultries': ['poultry'],
        'en:fresh-fruits': ['fruit'],
        'en:fresh-vegetables': ['vegetable'],
        'en:frozen-foods': ['frozen'],
        'en:canned-foods': ['canned'],
      };

      for (final entry in fallbackMapping.entries) {
        if (entry.value.any(cat.contains)) {
          final duration = _categoryDurations[entry.key];
          if (duration != null) {
            return baseDate.add(duration);
          }
        }
      }
    }

    return null;
  }
}
