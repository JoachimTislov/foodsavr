import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'line_item.dart';

/// A candidate product from the catalog, as seen by the matcher.
@immutable
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    this.barcode,
    this.keywords = const [],
  });

  final String id;
  final String name;
  final String? barcode;
  final List<String> keywords;
}

/// The best match for a [LineItem] within a product catalog, or none.
@immutable
class MatchResult {
  const MatchResult({this.product, this.confidence = 0});

  const MatchResult.none() : product = null, confidence = 0;

  final CatalogProduct? product;

  /// 0..1 similarity. 1 means an exact match (same name or same barcode).
  final double confidence;

  bool get hasMatch => product != null && confidence > 0;
}

/// Fuzzy-matches normalized item names against a product catalog.
///
/// Strategy, in order: exact barcode, exact normalized-name equality, then
/// token-based similarity (a Jaccard-style overlap blended with a bounded
/// Levenshtein ratio) — cheap, dependency-free, and good enough for grocery
/// names where brand tokens like "tine" dominate.
class FuzzyMatcher {
  FuzzyMatcher({this.exactThreshold = 0.99, this.minConfidence = 0.3});

  /// Confidence at/above which a match counts as exact.
  final double exactThreshold;

  /// Matches below this are discarded entirely.
  final double minConfidence;

  /// Returns the best match for [item] within [catalog].
  MatchResult match(LineItem item, Iterable<CatalogProduct> catalog) {
    if (item.barcode != null) {
      for (final p in catalog) {
        if (p.barcode == item.barcode) {
          return MatchResult(product: p, confidence: 1);
        }
      }
    }

    final queryTokens = _tokens(item.normalizedName);
    if (queryTokens.isEmpty) {
      return const MatchResult.none();
    }

    CatalogProduct? best;
    var bestScore = 0.0;
    for (final p in catalog) {
      final score = _similarity(queryTokens, _tokens(p.name), p.keywords);
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }

    if (best == null || bestScore < minConfidence) {
      return const MatchResult.none();
    }
    return MatchResult(product: best, confidence: bestScore.clamp(0, 1));
  }

  double _similarity(
    Set<String> query,
    Set<String> candidate,
    List<String> keywords,
  ) {
    if (candidate.isEmpty) return 0;
    var score = _jaccard(query, candidate);
    for (final k in keywords) {
      final kw = _tokens(k);
      if (kw.isEmpty) continue;
      score = score > _jaccard(query, kw) ? score : _jaccard(query, kw);
    }
    // Blend with a length-aware ratio so "melk" vs "melk" (1.0) beats
    // "melk" vs "chocolate milk drink" on equal token overlap.
    final joinedQuery = query.join(' ');
    final joinedCandidate = candidate.join(' ');
    final lev =
        1 -
        _levenshtein(joinedQuery, joinedCandidate) /
            _maxLen(joinedQuery, joinedCandidate);
    var blended = (score + (score > 0 ? lev : 0)) / 2;

    // Containment: "brødboller" contains "brød"; "hviteost" contains the
    // keyword "ost". Scaled with sqrt so long derivations still score well.
    final keywordTexts = [joinedCandidate, ...keywords.map(_joinTokens)];
    for (final k in keywordTexts) {
      final longer = joinedQuery.length >= k.length ? joinedQuery : k;
      final shorter = longer == joinedQuery ? k : joinedQuery;
      if (shorter.isEmpty || !longer.contains(shorter)) continue;
      final containment = math.sqrt(shorter.length / longer.length);
      blended = blended > containment ? blended : containment;
    }

    return blended >= exactThreshold && query.containsAll(candidate)
        ? 1.0
        : blended;
  }

  String _joinTokens(String s) => _tokens(s).join(' ');

  double _jaccard(Set<String> a, Set<String> b) {
    final intersection = a.where(b.contains).length;
    final union = a.union(b).length;
    return union == 0 ? 0 : intersection / union;
  }

  Set<String> _tokens(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9æøåßüöä]+'))
      .where((t) => t.isNotEmpty && t.length > 1)
      .toSet();

  int _maxLen(String a, String b) {
    if (a.length >= b.length) return a.length;
    return b.isEmpty ? 1 : b.length;
  }

  /// Classic two-row Levenshtein distance.
  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        curr[j + 1] = [
          curr[j] + 1,
          prev[j + 1] + 1,
          prev[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      prev = List.of(curr);
    }
    return prev[b.length];
  }
}
