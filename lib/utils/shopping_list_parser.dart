import '../constants/product_categories.dart';

/// A single item parsed from free-form shopping list text.
class ParsedShoppingItem {
  final String name;
  final int quantity;
  final String? category;

  const ParsedShoppingItem({
    required this.name,
    this.quantity = 1,
    this.category,
  });

  ParsedShoppingItem copyWith({String? name, int? quantity, String? category}) {
    return ParsedShoppingItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedShoppingItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          quantity == other.quantity &&
          category == other.category;

  @override
  int get hashCode => Object.hash(name, quantity, category);

  @override
  String toString() =>
      'ParsedShoppingItem(name: $name, quantity: $quantity, category: $category)';
}

/// Parses free-form text (multi-line, comma/semicolon-separated, bulleted, or
/// checklist notes) into normalized, deduplicated [ParsedShoppingItem] entries.
class ShoppingListParser {
  const ShoppingListParser._();

  static final RegExp _bulletPrefix = RegExp(
    r'^(?:[-*•◦▪–—]\s+|\d+[.)]\s+)',
    unicode: true,
  );
  static final RegExp _checkedPrefix = RegExp(
    r'^(?:\[[xX]\]|\([xX]\)|[☑✅✓✔])\s*',
    unicode: true,
  );
  static final RegExp _uncheckedPrefix = RegExp(
    r'^(?:\[\s*\]|\(\s*\)|☐)\s*',
    unicode: true,
  );

  // Quantity patterns.
  static final RegExp _prefixTimesQty = RegExp(
    r'^(\d+)\s*[xX×]\s*(.+)$',
    unicode: true,
  );
  static final RegExp _prefixBareQty = RegExp(r'^(\d+)\s+(.+)$', unicode: true);
  static final RegExp _countUnitPrefix = RegExp(
    r'^(?:stk\.?|pcs\.?|pc\.?)\s+(.+)$',
    caseSensitive: false,
    unicode: true,
  );
  static final RegExp _measurementUnitStart = RegExp(
    r'^(?:mg|g|kg|ml|cl|dl|l|oz|lb|lbs|tsp|tbsp|cups?)(?:\b|\.)',
    caseSensitive: false,
    unicode: true,
  );
  static final RegExp _suffixTimesQty = RegExp(
    r'^(.+?)\s*[xX×]\s*(\d+)$',
    unicode: true,
  );
  static final RegExp _suffixParenQty = RegExp(
    r'^(.+?)\s*\(\s*[xX×]?\s*(\d+)\s*[xX×]?\s*\)$',
    unicode: true,
  );
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Parses [input] into deduplicated [ParsedShoppingItem]s.
  ///
  /// Checked checklist items (`[x]`, `☑`, `✅`, `✓`) are skipped by default;
  /// pass [skipChecked] as `false` to include them.
  static List<ParsedShoppingItem> parse(
    String input, {
    bool skipChecked = true,
  }) {
    if (input.trim().isEmpty) return const [];

    final mergedByKey = <String, ParsedShoppingItem>{};
    final lines = input.split(RegExp(r'\r\n|\r|\n'));

    for (final rawLine in lines) {
      final cleanedLine = _stripPrefix(
        rawLine.trim(),
        skipChecked: skipChecked,
      );
      if (cleanedLine == null || cleanedLine.isEmpty) continue;

      final segments = cleanedLine.split(RegExp(r'[,;]'));
      for (final rawSegment in segments) {
        final cleanedSegment = _stripPrefix(
          rawSegment.trim(),
          skipChecked: skipChecked,
        );
        if (cleanedSegment == null || cleanedSegment.isEmpty) continue;

        final parsed = _parseSingleItem(cleanedSegment);
        if (parsed == null) continue;

        final key = parsed.name.toLowerCase();
        final existing = mergedByKey[key];
        if (existing != null) {
          mergedByKey[key] = existing.copyWith(
            quantity: existing.quantity + parsed.quantity,
          );
        } else {
          mergedByKey[key] = parsed;
        }
      }
    }

    return mergedByKey.values.toList();
  }

  /// Strips leading bullets/numbers and checkbox markers. Returns `null` when
  /// the entry is checked and [skipChecked] is true.
  static String? _stripPrefix(String value, {required bool skipChecked}) {
    var text = value;
    // Strip bullets and checkboxes in any order (e.g., "- [ ] Milk" or "[ ] - Milk").
    for (var i = 0; i < 3; i++) {
      final before = text;
      text = text.replaceFirst(_bulletPrefix, '').trimLeft();
      if (_checkedPrefix.hasMatch(text)) {
        if (skipChecked) return null;
        text = text.replaceFirst(_checkedPrefix, '').trimLeft();
      } else if (_uncheckedPrefix.hasMatch(text)) {
        text = text.replaceFirst(_uncheckedPrefix, '').trimLeft();
      }
      if (text == before) break;
    }
    return text.trim();
  }

  static ParsedShoppingItem? _parseSingleItem(String raw) {
    var name = raw.trim();
    var quantity = 1;

    if (_prefixTimesQty.firstMatch(name) case final match?) {
      quantity = _parsePositiveQuantity(match.group(1)!);
      name = match.group(2)!.trim();
    } else if (_suffixTimesQty.firstMatch(name) case final match?) {
      name = match.group(1)!.trim();
      quantity = _parsePositiveQuantity(match.group(2)!);
    } else if (_suffixParenQty.firstMatch(name) case final match?) {
      name = match.group(1)!.trim();
      quantity = _parsePositiveQuantity(match.group(2)!);
    } else if (_prefixBareQty.firstMatch(name) case final match?) {
      final remainder = match.group(2)!.trim();
      if (!_measurementUnitStart.hasMatch(remainder)) {
        quantity = _parsePositiveQuantity(match.group(1)!);
        final countUnitMatch = _countUnitPrefix.firstMatch(remainder);
        name = countUnitMatch != null
            ? countUnitMatch.group(1)!.trim()
            : remainder;
      }
    }

    name = name.replaceAll(_whitespace, ' ').trim();
    if (name.isEmpty) return null;

    return ParsedShoppingItem(
      name: name,
      quantity: quantity,
      category: ProductCategory.inferFromName(name),
    );
  }

  static int _parsePositiveQuantity(String digits) {
    final value = int.tryParse(digits) ?? 1;
    return value < 1 ? 1 : value;
  }
}
