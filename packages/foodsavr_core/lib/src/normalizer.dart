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
    r'^(\d+(?:[.,]\d+)?)\s*(ml|l|ltr|liter|g|kg|stk|stykk|pc|pcs|pk|pkk|pack|pakke|ea)\b[\s.-]*',
    caseSensitive: false,
  );

  /// Quantity-only prefix, e.g. "2 STK TINE MELK".
  static final RegExp _bareQuantityPrefix =
      RegExp(r'^(\d+(?:[.,]\d+)?)\s+(?=\S)', caseSensitive: false);

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
  NormalizedName normalize(String raw, {double fallbackQuantity = 1}) {
    var text = raw.trim().toLowerCase();

    var quantity = fallbackQuantity;
    var unit = LineItemUnit.piece;

    var m = _quantityPrefix.firstMatch(text);
    if (m != null) {
      quantity = double.parse(m.group(1)!.replaceAll(',', '.'));
      unit = _unitTokens[m.group(2)!.toLowerCase()] ?? LineItemUnit.piece;
      text = text.substring(m.group(0)!.length);
    } else {
      m = _bareQuantityPrefix.firstMatch(text);
      if (m != null) {
        quantity = double.parse(m.group(1)!.replaceAll(',', '.'));
        text = text.substring(m.group(0)!.length);
      }
    }

    // Also consume a trailing "<amount> <unit>" like "melk 1 l".
    final trailing = _quantityPrefix.firstMatch(' ${text}');
    if (trailing != null && trailing.start > 0) {
      final tail = text.substring(text.length - trailing.group(0)!.length + 1);
      final tailMatch = RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(ml|l|ltr|liter|g|kg|stk|stykk|pc|pcs|pk|pkk|pack|pakke|ea)\s*$',
        caseSensitive: false,
      ).firstMatch(text);
      if (tailMatch != null) {
        quantity = double.parse(tailMatch.group(1)!.replaceAll(',', '.'));
        unit = _unitTokens[tailMatch.group(2)!.toLowerCase()] ?? unit;
        text = text.substring(0, tailMatch.start);
      }
      // tail only used for the guard; ignore otherwise.
      assert(tail.isNotEmpty || tail.isEmpty);
    }

    text = text
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), ' ')
        .replaceAll(_noiseSuffix, ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    return NormalizedName(
      name: text,
      quantity: quantity,
      unit: unit,
    );
  }
}

/// Result of [Normalizer.normalize].
class NormalizedName {
  const NormalizedName({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final double quantity;
  final LineItemUnit unit;
}
