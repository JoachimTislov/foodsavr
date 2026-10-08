import 'line_item.dart';

/// Normalizes raw grocery item text: case, whitespace, unit synonyms,
/// and quantity extraction.
class Normalizer {
  static const _unitSynonyms = <String, String>{
    'l': 'l',
    'liter': 'l',
    'litre': 'l',
    'liters': 'l',
    'ml': 'ml',
    'kg': 'kg',
    'kilo': 'kg',
    'kilogram': 'kg',
    'g': 'g',
    'gram': 'g',
    'grams': 'g',
    'stk': 'stk',
    'stykke': 'stk',
    'pk': 'pk',
    'pcs': 'stk',
    'pcs.': 'stk',
  };

  static final _quantityPattern = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(l|liter|litre|liters|ml|kg|kilo|kilogram|g|gram|grams|stk|stykke|pk|pcs)',
    caseSensitive: false,
  );

  /// Normalizes name text: trims, collapses whitespace, lowercases,
  /// and canonicalizes unit synonyms.
  String normalizeName(String input) {
    final collapsed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    final words = collapsed
        .split(' ')
        .map((w) => _normalizeWord(w))
        .where((w) => w.isNotEmpty)
        .toList();
    return words.join(' ');
  }

  String _normalizeWord(String word) {
    var w = word.toLowerCase();
    if (_unitSynonyms.containsKey(w)) {
      return _unitSynonyms[w]!;
    }
    return w;
  }

  /// Extracts quantity and unit from raw text like "1l milk" or "Milk 2 stk".
  /// Returns null when no explicit quantity/unit is found.
  ({double quantity, String unit})? extractQuantity(String input) {
    final match = _quantityPattern.firstMatch(input);
    if (match == null) return null;
    final quantity =
        double.parse(match.group(1)!.replaceAll(',', '.'));
    final unit = _unitSynonyms[match.group(2)!.toLowerCase()]!;
    return (quantity: quantity, unit: unit);
  }

  /// Builds a normalized [LineItem] from raw input.
  LineItem normalize(LineItem item) {
    final extracted = extractQuantity(item.rawName);
    final normalizedName = normalizeName(item.rawName);
    return item.copyWith(
      normalizedName: normalizedName,
      quantity: extracted?.quantity ?? item.quantity,
      unit: extracted?.unit ?? item.unit,
    );
  }
}
