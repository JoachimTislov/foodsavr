# foodsavr_core

Pure-Dart package holding the shared FoodSavr ingestion logic so the Flutter
app and the future MCP server (#171) consume one implementation.

## Contents

- `LineItem` — unified model for any ingested grocery item (receipt, grocery
  API, barcode, or free text), with JSON round-trip support.
- `Normalizer` — case/whitespace/unit-synonym normalization plus
  quantity/unit extraction from raw names.
- `FuzzyMatcher` — Levenshtein + token-set similarity matching against a
  product catalog.
- `ShelfLifeInferer` — category-based default shelf life with per-product
  overrides.
- `ConfidenceGate` — classifies items into auto-add / confirm / hold based on
  match confidence thresholds.

## Usage

```dart
import 'package:foodsavr_core/foodsavr_core.dart';

final normalizer = Normalizer();
final item = normalizer.normalize(
  LineItem(rawName: '1l Milk', quantity: 1, source: LineItemSource.receipt),
);
final match = FuzzyMatcher(catalog: {'p1': 'milk 1l'}).bestMatch(item);
final gated = ConfidenceGate().evaluate(item.copyWith(
  productId: match?.productId,
  matchConfidence: match?.confidence,
));
final days = ShelfLifeInferer().inferDays(category: 'dairy');
```

No Flutter, Firebase, or IO dependencies — runs anywhere Dart does.
