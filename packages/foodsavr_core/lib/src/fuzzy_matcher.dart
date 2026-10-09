import 'line_item.dart';

/// Levenshtein-based fuzzy matcher against a product catalog.
class FuzzyMatcher {
  FuzzyMatcher({required Map<String, String> catalog}) : _catalog = catalog;

  /// Maps catalog product id -> product name.
  final Map<String, String> _catalog;

  /// Returns the best match (productId, confidence in 0..1), or null when
  /// nothing scores above [minConfidence].
  ({String productId, double confidence})? bestMatch(
    LineItem item, {
    double minConfidence = 0.4,
  }) {
    final query = (item.normalizedName ?? item.rawName).toLowerCase();
    if (query.trim().isEmpty) return null;

    String? bestId;
    var bestScore = 0.0;
    for (final entry in _catalog.entries) {
      final score = _similarity(query, entry.value.toLowerCase());
      if (score > bestScore) {
        bestScore = score;
        bestId = entry.key;
      }
    }
    if (bestId == null || bestScore < minConfidence) return null;
    return (productId: bestId, confidence: bestScore);
  }

  /// Token-set + Levenshtein hybrid similarity in 0..1.
  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    final distance = _levenshtein(a, b);
    final charScore = 1.0 - distance / maxLen;
    final tokenScore = _tokenSetScore(a, b);
    return charScore > tokenScore ? charScore : tokenScore;
  }

  double _tokenSetScore(String a, String b) {
    final at = a.split(' ').toSet();
    final bt = b.split(' ').toSet();
    if (at.isEmpty && bt.isEmpty) return 1.0;
    if (at.isEmpty || bt.isEmpty) return 0.0;
    final intersection = at.intersection(bt).length;
    return 2.0 * intersection / (at.length + bt.length);
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    var prev = List<int>.generate(t.length + 1, (i) => i);
    var curr = List<int>.filled(t.length + 1, 0);

    for (var i = 0; i < s.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        curr[j + 1] = [
          prev[j + 1] + 1,
          curr[j] + 1,
          prev[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[t.length];
  }
}
