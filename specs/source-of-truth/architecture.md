# Architecture

## Current state (absorbed from code @ 103a70f)

Flutter/Firebase app with layered architecture (see root `INDEX.md` and `doc/implementation/product-architecture-refactor.md`):

- **UI** (`lib/views/`, `lib/widgets/`) — screens and reusable components; services injected via `getIt<Service>()`; controller layer with `watch_it` reactivity for dashboard and collection lists.
- **Adaptive layout** (`lib/constants/adaptive_layout.dart`) — Material 3 window size classes: compact (<600 dp) uses the bottom navigation bar; medium (600-839) and expanded (>=840) use a navigation rail (labels beside icons from 1200); expanded windows show list and detail side by side (`MasterDetailLayout`) and cap page content at a readable width.
- **Service** (`lib/services/`, `lib/features/third_party_integration/services/`) — business logic; depends on repository interfaces.
- **Data** (`lib/interfaces/`, `lib/repositories/`) — `i_repository` base contract and feature contracts.
- **Domain** (`lib/models/`) — plain data classes with `toJson`/`fromJson`.
- **Shared core** (`packages/foodsavr_core/`) — pure Dart package: `line_item.dart`, `normalizer.dart`, `matcher.dart`, `shelf_life.dart`, `confidence_gate.dart`, `pipeline.dart`. The skeleton landed in #202; app-side ingestion does not yet route through it.

Working features: inventory core (products, collections, transfers), Open Food Facts enrichment, ML Kit barcode scanning, OCR expiry scanning, receipt ingestion via `receipt_recognition`, Rema third-party integration.

## Target architecture (spec-ahead)

Vision: FoodSavr is an adapter, not a duplicate architecture — normalize any food input into a unified LineItem, then auto-generate grocery lists with zero-to-one user interactions.

1. **Universal ingestion pipeline** — receipts, loyalty APIs (Rema/Coop/Trumf), order systems, recipes, barcodes, free text → LineItem via `foodsavr_core` (normalization → fuzzy matching → shelf-life inference → confidence-based confirmation).
2. **Thin in-app agent** — orchestrates existing services; no parallel logic.
3. **Remote MCP server** — streamable HTTP, OAuth 2.1, exposing `ingest_receipt`, `read_orders`, `generate_shopping_list` (#171); logic shared with the app via `foodsavr_core`.
4. **Hybrid event log and CRUD** — data derived from raw sources flows inbox → ordered domain events → read-only projections; only user-authored data is CRUD. A Dart worker on Cloud Run (co-located with the MCP server) runs the pipeline and projectors. See [ADR 0005](decisions/0005-hybrid-event-log-and-crud.md).
5. **Feature modules and entitlements** ([ADR 0008](decisions/0008-feature-modules-entitlements-and-plans.md)) — every capability is a module in a bundled catalog ([registries/feature-modules.yaml](registries/feature-modules.yaml), shape [contracts/feature-registry.schema.json](contracts/feature-registry.schema.json)). A resolver decides which modules are enabled (order in the ADR); plan state is [contracts/entitlement.schema.json](contracts/entitlement.schema.json), with RevenueCat as the source of truth.
6. **Legal documents per environment** ([ADR 0009](decisions/0009-legal-documents-per-environment.md)) — one manifest per environment ([contracts/legal-documents.schema.json](contracts/legal-documents.schema.json)) feeds both the app and the environment's landing page (#371); acceptance is versioned per user.

## Boundaries

- `foodsavr_core` is pure Dart, no Flutter or Firebase imports; both the app and MCP server depend on it, never the reverse.
- Firestore collections: `products`, `collections` today; users, shopping lists, recipes, meals, groups are spec'd but unbuilt (#195–#197).
- Feature call sites ask the module resolver, never a plan, a flag or RevenueCat directly (ADR 0008).
- Firestore rules are tracked in `firestore.rules`; CI tests that file in the Firestore emulator, and deploys are manual (`make infra-gcp-apply` through Terraform, or the `make deploy-firestore-rules` bypass) until the release pipeline deploys them ([ADR 0010](decisions/0010-track-firestore-rules-during-test-phase.md), superseding #165/#185).
