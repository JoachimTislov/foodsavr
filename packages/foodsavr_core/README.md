# foodsavr_core

Shared FoodSavr domain logic, consumed by the Flutter app and the planned MCP
server (#171) so ingestion logic exists exactly once.

Pure Dart — no Flutter, no Firebase. Keep it that way: this package must stay
portable to a server context.

## What's in it

The universal ingestion pipeline:

```
raw input (receipt / loyalty API / barcode / free text)
  -> Normalizer          (LineItem: raw name -> normalized name, qty, unit)
  -> FuzzyMatcher         (against the product catalog; barcode = exact)
  -> ShelfLifeInferer     (category-based default expiry, overridable)
  -> ConfidenceGate       (autoAdd / confirm / hold)
```

- **`LineItem`** — the unified format every ingestion source normalizes into.
- **`Normalizer`** — case folding, whitespace, unit synonyms (incl. Norwegian
  grocery tokens: STK, KG, PAKKE…), embedded quantity extraction.
- **`FuzzyMatcher`** — barcode exact-match short-circuit, then token-set
  (Jaccard) similarity blended with a bounded Levenshtein ratio.
- **`ShelfLifeInferer`** — coarse keyword categories (dairy, meat, fish,
  produce, bakery, pantry, frozen, beverages) with default day counts.
- **`ConfidenceGate`** — thresholds decide whether an item lands in inventory
  silently (autoAdd), needs a one-tap confirmation, or is held back.
- **`IngestionPipeline`** — orchestrates the above; one entry point per source.

## Usage

```dart
final pipeline = IngestionPipeline();
final results = pipeline.processAll(rawItems, catalogProducts);
for (final r in results) {
  if (r.decision == ConfidenceDecision.autoAdd) { /* add to inventory */ }
  if (r.needsConfirmation) { /* surface to user */ }
}
```

## Conventions

- Every public class is immutable; `copyWith` for changes.
- No I/O, no platform channels, no secrets. If a change needs any of that,
  it belongs in the app layer, not here.

## Status

Skeleton (tracked in #191). The app does not consume this package yet —
rewiring receipt/Rema/barcode ingestion is #192.
