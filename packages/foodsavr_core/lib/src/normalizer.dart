import 'line_item.dart';

/// Cleans raw item names into a canonical form used for matching.
///
/// Handles case folding, whitespace collapsing, unit synonyms, quantity
/// prefixes ("2L MILK" -> "milk", quantity 2, unit liter) and common
/// Norwegian grocery tokens (STK, KG, PK).
class Normalizer {
  static final Map<String, LineItemUnit> _unitTokens = {
    'pc': LineItemUnit.piece,
    'pcs': LineItemUnit.piece,
    'stk': LineItemUnit.piece,
    'stykk': LineItemUnit.piece,
    'ea': LineItemUnit.piece,
    'g': LineItemUnit.gram,
    'gram': LineItemUnit.gram,
    'kg': LineItemUnit.kilogram,
    'l': LineItemUnit.liter,
    'liter': LineItemUnit.liter,
    'ltr': LineItemUnit.liter,
    'ml': LineItemUnit.milliliter,
    'pk': LineItemUnit.package,
    'pkk': LineItemUnit.package,
    'pack': LineItemUnit.package,
    'pakke': LineItemUnit.package,
  };

  static final RegExp _quantityPrefix = RegExp(
    r'^(\d+(?:[.,]\d+)?)\s*(ml|ltr|liter|l|kg|stykk|stk|gram|g|pcs|pc|pakke|pack|pkk|pk|ea)\b[\s.-]*',
    caseSensitive: false,
  );

  /// Quantity-only prefix, e.g. "2 STK TINE MELK".
  static final RegExp _bareQuantityPrefix = RegExp(
    r'^(\d+(?:[.,]\d+)?)\s+(?=\S)',
    caseSensitive: false,
  );

  static final RegExp _trailingQuantity = RegExp(
    r'\s+(\d+(?:[.,]\d+)?)\s*(ml|ltr|liter|l|kg|stykk|stk|gram|g|pcs|pc|pakke|pack|pkk|pk|ea)\s*$',
    caseSensitive: false,
  );

  static final RegExp _noiseSuffix = RegExp(
    r'\b(gratis|tilbud|rabatt|discount|offer)\b',
    caseSensitive: false,
  );

  /// Splits [raw] into a normalized name and, when a quantity with a unit
  /// is embedded in the text, an updated [quantity]/[unit].
  ///
  /// Examples:
  /// - `'1l milk'` -> `('milk', 1, liter)`
  /// - `'MELK 1 L'` -> `('melk', 1, liter)`
  /// - `'2 STK TINE MELK'` -> `('tine melk', 2, piece)`
  /// - `'Ice Cream!!  '` -> `('ice cream', 1, piece)`
  NormalizedName normalize(
    String raw, {
    double fallbackQuantity = 1,
    LineItemUnit fallbackUnit = LineItemUnit.piece,
  }) {
    var text = raw.trim().toLowerCase();

    var quantity = fallbackQuantity;
    var unit = fallbackUnit;

    var m = _quantityPrefix.firstMatch(text);
    if (m != null) {
      quantity = double.parse(m.group(1)!.replaceAll(',', '.'));
      unit = _unitTokens[m.group(2)!.toLowerCase()] ?? unit;
      // Keep the original text when the prefix consumes everything, so a
      // quantity-only input like "500g" still yields a usable name.
      if (m.group(0)!.length < text.length) {
        text = text.substring(m.group(0)!.length);
      }
    } else {
      m = _bareQuantityPrefix.firstMatch(text);
      if (m != null) {
        quantity = double.parse(m.group(1)!.replaceAll(',', '.'));
        text = text.substring(m.group(0)!.length);
      }
    }

    // Also consume a trailing "<amount> <unit>" like "melk 1 l". Requires
    // preceding name text so a quantity-only input is not emptied out.
    final tailMatch = _trailingQuantity.firstMatch(text);
    if (tailMatch != null && tailMatch.start > 0) {
      quantity = double.parse(tailMatch.group(1)!.replaceAll(',', '.'));
      unit = _unitTokens[tailMatch.group(2)!.toLowerCase()] ?? unit;
      text = text.substring(0, tailMatch.start);
    }

    text = text
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), ' ')
        .replaceAll(_noiseSuffix, ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    return NormalizedName(name: text, quantity: quantity, unit: unit);
  }
}

/// Result of [Normalizer.normalize].
class NormalizedName {
  const NormalizedName({required this.name, required this.quantity, this.unit});

  final String name;
  final double quantity;

  /// Extracted unit, null when the input carried no unit information.
  final LineItemUnit? unit;
}
