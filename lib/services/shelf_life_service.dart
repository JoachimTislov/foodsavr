import 'package:injectable/injectable.dart';
import '../models/product_model.dart';

@lazySingleton
class ShelfLifeService {
  /// A heuristic mapping of Open Food Facts category tags to a default shelf life duration.
  /// This serves as the "Smart Default" layer for zero-interaction expiration estimation.
  final Map<String, Duration> _categoryDurations = {
    // Dairy & Eggs
    'en:milks': const Duration(days: 10),
    'en:yogurts': const Duration(days: 14),
    'en:cheeses': const Duration(days: 30),
    'en:eggs': const Duration(days: 28),
    'en:butter': const Duration(days: 90),

    // Meats & Fish
    'en:fresh-meats': const Duration(days: 4),
    'en:poultries': const Duration(days: 4),
    'en:fishes': const Duration(days: 2),
    'en:seafood': const Duration(days: 2),
    'en:processed-meats': const Duration(days: 14), // e.g., sausages, ham
    // Bakery
    'en:breads': const Duration(days: 5),
    'en:pastries': const Duration(days: 3),

    // Produce
    'en:fresh-fruits': const Duration(days: 7),
    'en:fresh-vegetables': const Duration(days: 7),
    'en:salads': const Duration(days: 5),

    // Pantry / Long-term
    'en:canned-foods': const Duration(days: 730), // 2 years
    'en:dried-products': const Duration(days: 365), // 1 year
    'en:pastas': const Duration(days: 730),
    'en:rice': const Duration(days: 730),
    'en:cereals': const Duration(days: 365),
    'en:condiments': const Duration(days: 180),
    'en:sauces': const Duration(days: 365),
    'en:snacks': const Duration(days: 180),
    'en:beverages': const Duration(days: 365),

    // Frozen
    'en:frozen-foods': const Duration(days: 180), // 6 months
    'en:ice-creams': const Duration(days: 180),
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
