# Ingestion Pipeline

## Built (absorbed from code @ 103a70f)

- Receipt ingestion: `lib/services/receipt_ingestion_service.dart` using Google `receipt_recognition` (#184).
- Barcode scanning: `lib/services/barcode_scanner_service.dart` (ML Kit).
- Expiry scanning: `lib/services/expiry_scanner_service.dart` (OCR).
- Open Food Facts enrichment: `lib/services/product_service.dart`.
- `foodsavr_core` pipeline skeleton: normalization → matching → shelf-life inference → confidence gate (`packages/foodsavr_core/lib/src/pipeline.dart`), landed in #202 but not yet wired into app ingestion paths.

## Spec-ahead (target pipeline)

All input sources route through `foodsavr_core`'s pipeline into LineItem (#191 → #192 → #193):

1. **Normalize** any food input (receipt, loyalty API, order, recipe, barcode, free text) into LineItem.
2. **Fuzzy match** against existing products and Open Food Facts.
3. **Infer shelf-life** where unknown.
4. **Confidence gate** — low-confidence items surface to a confirmation UI (#193); high-confidence items land with zero-to-one user interactions.

## Known drift (finding for the loop)

Receipt, Rema, and barcode paths each enrich products separately; unification through the pipeline is tracked in #192 and is contract work, not something a sync session "fixes".
