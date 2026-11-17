# Data Model

## Built (absorbed from code @ 103a70f)

- Firestore collections: `products`, `collections`.
- Domain models in `lib/models/` — plain data classes with `toJson`/`fromJson`, registered via DI repositories (`i_product_repository`, `i_collection_repository`, …).
- `foodsavr_core` defines the universal `LineItem` (`packages/foodsavr_core/lib/src/line_item.dart`) — the canonical normalized format for any food input.

## Shapes (authoritative, per ADR 0004)

Field-level truth lives in JSON Schemas validated against code by `scripts/ci/check_shape_sync.dart` in CI:

- [schemas/line-item.schema.json](schemas/line-item.schema.json) — anchor `packages/foodsavr_core/lib/src/line_item.dart`
- [schemas/product.schema.json](schemas/product.schema.json) — anchor `lib/models/product_model.dart`
- [schemas/collection.schema.json](schemas/collection.schema.json) — anchor `lib/models/collection_model.dart`

## Spec-ahead (unimplemented)

Per #212 and `doc/implementation/`:

- Shopping lists, meal plans, recipes, groups/family collections as Firestore collections covered by owner/group rules (#195, #196, #197).
- Offline support and sync for Firestore data (TODO.md).
- Composite indexes guided by `firestore.indexes.json`.

Sync sessions: a model file's claims are checked against `lib/models/` and `packages/foodsavr_core/lib/src/line_item.dart`. Items above under "Spec-ahead" are contract decisions, not drift.
