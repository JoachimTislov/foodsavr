import 'package:meta/meta.dart';

import 'confidence_gate.dart';
import 'line_item.dart';
import 'matcher.dart';
import 'normalizer.dart';
import 'shelf_life.dart';

/// A fully processed item: the normalized [LineItem] plus the match found
/// (if any), the gate decision, and the inferred shelf life.
@immutable
class PipelineResult {
  const PipelineResult({
    required this.item,
    required this.match,
    required this.decision,
    this.shelfLifeDays,
  });

  final LineItem item;
  final MatchResult match;
  final ConfidenceDecision decision;
  final int? shelfLifeDays;

  bool get needsConfirmation => decision == ConfidenceDecision.confirm;
}

/// The universal ingestion pipeline:
/// normalize -> fuzzy match -> shelf-life inference -> confidence gate.
///
/// Same entry point for every source (receipts, loyalty APIs, barcodes, free
/// text); the source only affects which [LineItem] fields are pre-populated.
class IngestionPipeline {
  IngestionPipeline({
    Normalizer? normalizer,
    FuzzyMatcher? matcher,
    ShelfLifeInferer? shelfLife,
    ConfidenceGate? gate,
  }) : _normalizer = normalizer ?? Normalizer(),
       _matcher = matcher ?? FuzzyMatcher(),
       _shelfLife = shelfLife ?? ShelfLifeInferer(),
       _gate = gate ?? ConfidenceGate();

  final Normalizer _normalizer;
  final FuzzyMatcher _matcher;
  final ShelfLifeInferer _shelfLife;
  final ConfidenceGate _gate;

  /// Runs one raw input through the full pipeline.
  PipelineResult process(LineItem input, Iterable<CatalogProduct> catalog) {
    final normalized = _normalizer.normalize(input.rawName);
    var item = input.copyWith(
      normalizedName: normalized.name,
      quantity: normalized.quantity,
      unit: normalized.unit,
    );

    // Barcode hits are always exact.
    final match = _matcher.match(item, catalog);
    if (match.hasMatch) {
      item = item.copyWith(
        matchedProductId: match.product!.id,
        matchConfidence: match.confidence,
      );
    }

    final shelfLifeDays = _shelfLife.infer(item);
    if (shelfLifeDays != null) {
      item = item.copyWith(inferredShelfLifeDays: shelfLifeDays);
    }

    return PipelineResult(
      item: item,
      match: match,
      decision: _gate.decide(match),
      shelfLifeDays: shelfLifeDays,
    );
  }

  /// Processes a batch; order preserved.
  List<PipelineResult> processAll(
    Iterable<LineItem> inputs,
    Iterable<CatalogProduct> catalog,
  ) => inputs.map((i) => process(i, catalog)).toList();
}
