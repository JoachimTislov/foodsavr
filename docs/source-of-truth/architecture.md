# Architecture

## Current state (absorbed from code @ 103a70f)

Flutter/Firebase app with layered architecture (see root `INDEX.md` and `doc/implementation/product-architecture-refactor.md`):

- **UI** (`lib/views/`, `lib/widgets/`) — screens and reusable components; services injected via `getIt<Service>()`; controller layer with `watch_it` reactivity for dashboard and collection lists.
- **Service** (`lib/services/`, `lib/features/third_party_integration/services/`) — business logic; depends on repository interfaces.
- **Data** (`lib/interfaces/`, `lib/repositories/`) — `i_repository`/`i_service` base contracts and feature contracts.
- **Domain** (`lib/models/`) — plain data classes with `toJson`/`fromJson`.
- **Shared core** (`packages/foodsavr_core/`) — pure Dart package: `line_item.dart`, `normalizer.dart`, `matcher.dart`, `shelf_life.dart`, `confidence_gate.dart`, `pipeline.dart`. The skeleton landed in #202; app-side ingestion does not yet route through it.

Working features: inventory core (products, collections, transfers), Open Food Facts enrichment, ML Kit barcode scanning, OCR expiry scanning, receipt ingestion via `receipt_recognition`, Rema third-party integration.

## Target architecture (spec-ahead)

Vision: FoodSavr is an adapter, not a duplicate architecture — normalize any food input into a unified LineItem, then auto-generate grocery lists with zero-to-one user interactions.

1. **Universal ingestion pipeline** — receipts, loyalty APIs (Rema/Coop/Trumf), order systems, recipes, barcodes, free text → LineItem via `foodsavr_core` (normalization → fuzzy matching → shelf-life inference → confidence-based confirmation).
2. **Thin in-app agent** — orchestrates existing services; no parallel logic.
3. **Remote MCP server** — streamable HTTP, OAuth 2.1, exposing `ingest_receipt`, `read_orders`, `generate_shopping_list` (#171); logic shared with the app via `foodsavr_core`.

## Boundaries

- `foodsavr_core` is pure Dart, no Flutter or Firebase imports; both the app and MCP server depend on it, never the reverse.
- Firestore collections: `products`, `collections` today; users, shopping lists, recipes, meals, groups are spec'd but unbuilt (#195–#197).
- Firestore rules are deliberately untracked; CI validates them via `FIRESTORE_RULES_B64` secret (#165/#185).
