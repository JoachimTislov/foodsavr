# FoodSavr — Project Context & Agent Integration Vision

This document is the canonical context brief for FoodSavr. It describes the product
vision, the current state of the codebase, and the roadmap toward making FoodSavr the
low-friction adapter layer for everything food-related — consumable by humans, agents,
and MCP-compatible clients alike.

## 1. Product Vision

**End goal: remove all friction from grocery shopping.**

FoodSavr is not trying to replace reliable services. It is an **adapter** (and a
**standalone fallback** when no service exists) that:

- Decodes and interprets **virtually any food-related input**: receipts (digital and
  scanned), barcodes/EAN/GTIN, order confirmations (e.g., Pizzabakeren email/SMS
  orders), recipes from arbitrary websites, meal plans, free-text ("buy milk"),
  grocery-store loyalty APIs, and structured catalogs (Open Food Facts).
- Normalizes everything into a **unified internal format** (`Product`, `Collection`,
  future `Receipt`/`LineItem` models) from which a grocery list can be generated
  automatically with minimal user interaction.
- Exposes this capability through **two interfaces**:
  1. **FoodSavr's own agent** — the in-app experience that performs the automatic
     grocery-list generation end-to-end (scan → interpret → match inventory → list).
  2. **An MCP server** — so Claude, Codex, and virtually any agent ecosystem can use
     FoodSavr as a toolset: read inventory, ingest receipts/orders, generate and
     manage shopping lists — without duplicating what FoodSavr already does well.
- Supports **OAuth for relevant third-party systems** (grocery loyalty programs,
  receipt providers, identity providers), always acting on the user's behalf with
  explicit consent (BYOC — Bring Your Own Credentials).

### Non-negotiable principles

- **Adapter, not duplicate.** If a reliable upstream service exists (Open Food Facts,
  Storebox RDA, grocery loyalty APIs), FoodSavr integrates with it rather than
  building a parallel dataset. FoodSavr only fills gaps (fuzzy receipt-line matching,
  shelf-life heuristics, unified normalization).
- **Free of charge for non-commercial use.**
- **Low-effort interface.** The measure of success is the number of interactions
  between "I bought food" and "my grocery list is updated": target is zero or one.

## 2. Current State of the Codebase

### Stack

- **Flutter** (Dart >= 3.10, Flutter >= 3.32), Material 3, `easy_localization` (nb/en).
- **Firebase**: Auth (email, Google, Facebook; Vipps planned), Firestore
  (`products`, `collections` collections; `users`, `shoppingLists`, `mealPlans`,
  `recipes`, `inventory` spec'd in `doc/implementation/firebase-store/`), App Check.
- **DI**: `injectable` + `get_it` (`lib/service_locator.dart`, `lib/injection.dart`).
- **Routing**: `go_router` (`lib/routes/`).
- **Key libs**: `openfoodfacts` (product enrichment), ML Kit (barcode + text
  recognition), `camera`, `webview_flutter` (OAuth flows), `flutter_secure_storage`
  (token storage), `http` + `RetryClient`, `freezed`/`json_serializable` for models.

### Architecture (3-tier layered)

| Layer | Location | Role |
| :--- | :--- | :--- |
| UI | `lib/views/`, `lib/widgets/` | Screens and components; inject services via `getIt` |
| Service | `lib/services/`, `lib/features/*/services/` | Business logic, validation, orchestration |
| Data | `lib/interfaces/`, `lib/repositories/` | Contracts + Firestore implementations |
| Domain | `lib/models/` | Freezed data classes with `toJson`/`fromJson` |

Feature pattern for new work (from `INDEX.md`):
model → interface → repository → service → DI registration → UI → tests.

### What exists today

- **Inventory core**: products and collections CRUD, expiration tracking
  (`ProductStatus` fresh/expiring/expired), dashboard with expiring-soon overview,
  barcode scanning with Open Food Facts enrichment, ML Kit receipt text
  recognition, shelf-life heuristics by category (`lib/utils/shelf_life.dart`).
- **Third-party integration feature** (`lib/features/third_party_integration/`):
  - `IOAuthService` / `OAuthService` — webview-driven authorization flows.
  - `Provider` enum — Coop (Coop Medlem), Rema (Æ), Trumf (NorgesGruppen).
  - `Client` base class — retrying HTTP client, per-provider env config, token
    retrieval from secure storage.
  - `RemaClient` — implemented: fetches transaction heads → row details, maps to
    `Product` (EAN via `prodtxt3`).
  - `CoopClient` — scaffolded, endpoints documented but stubbed.
  - Models for Rema transaction heads/rows/details/payments.
  - `Connection` model + `ConnectionsList` UI in settings.
- **Planned/spec'd but not built**: shopping lists, meal plans, recipes, groups,
  users collection (docs in `doc/implementation/firebase-store/`).

### Documented integration research

- `doc/plan/grocery-private-api-integration.md` — reverse-engineered Norwegian
  grocery APIs (Rema `id.rema.no` PKCE, Coop Auth0, Trumf password grant), unified
  receipt normalization strategy, sync watermarking, ToS/GDPR consent considerations.
- `doc/research/storebox_integration.md` — Storebox (Nets/Nexi) RDA research; B2B
  official API vs. reverse-engineered consumer flows; recommended backend proxy
  (Cloud Functions), mock-first phased approach.
- `doc/plan/oauth2_pkce_flow.md`, `doc/plan/sql-db/` — auth flow and future
  persistence options.

## 3. Target Capabilities (Roadmap)

### 3.1 Universal food-data interpretation ("decode anything")

A canonical **ingestion pipeline** where every source normalizes to a common
intermediate format before hitting inventory/shopping-list logic:

```
source (receipt scan | digital receipt API | order email/SMS | recipe URL |
       barcode | free text | grocery API)
   → fetch/extract
   → normalize (LineItem: name, EAN?, quantity, price, unit, currency, store, time)
   → interpret (fuzzy-match to global products catalog / Open Food Facts,
       infer category + shelf life)
   → user-confirmation step (optional, zero-step when confidence is high)
   → inventory / shopping list
```

Source adapters to support (each a `Client`/parser implementing a shared
`IImportService`-style contract):

| Source | Type | Status |
| :--- | :--- | :--- |
| Barcode → Open Food Facts | enrichment | done |
| Receipt photo (ML Kit OCR) | ingestion | partial (scan exists; mapping layer missing) |
| Rema Æ transactions | ingestion | implemented (client) |
| Coop Medlem history | ingestion | stubbed |
| Trumf (Kiwi/Meny/Spar/Joker) | ingestion | documented, not built |
| Storebox RDA (Nordic receipts) | ingestion | researched (needs B2B agreement) |
| **Pizzabakeren and similar order systems** (email/SMS/app order reads) | ingestion | not started — parse order confirmations into `LineItem`s |
| Recipe websites | ingestion → recipes | not started |
| Free text / voice | ingestion | not startate — natural fit for the agent |
| Global product catalog (admin-curated, user voting) | enrichment | spec'd |

Key design rule: **adapters never write directly to Firestore.** They emit normalized
`LineItem`s; services own persistence, dedup, and list generation.

### 3.2 OAuth for third-party systems

- Generalize the existing `IOAuthService`/`Client` pattern into a registry so any
  provider (Rema PKCE, Coop Auth0 OIDC, Trumf direct grant, Storebox web session,
  Google/Facebook/Vipps identity) plugs in with a small descriptor:
  `ProviderDescriptor { authKind, endpoints, scopes, tokenStorage, pollers }`.
- Store refresh tokens in `flutter_secure_storage` / server-side KMS; never
  passwords where avoidable; encrypt at rest when unavoidable (Trumf).
- Reconnect UX: when a provider's private API breaks (they will — see WhatIBuy
  precedent), surface "Reconnect [Store]" prompts; monitor 401/403/404 per provider.
- GDPR posture: explicit per-provider consent screen; user-initiated sync;
  data minimization (keep only line items needed for inventory/list).

### 3.3 FoodSavr's own agent

An in-app agent that composes existing services into the zero-effort flow:

1. Watches connected sources (push/poll digital receipts, new order confirmations).
2. Interprets incoming `LineItem`s (OCR receipt parsing, order parsing, fuzzy
   catalog matching, shelf-life inference).
3. Diffs against current inventory and planned meals.
4. Auto-generates/updates the grocery list (dedup + merge), needs
   `shoppingLists` implementation (`doc/implementation/firebase-store/shopping-lists.md`).
5. Surfaces one-tap confirmations instead of forms.

The agent is intentionally thin: it orchestrates `ProductService`,
`ShelfLifeService`, the import services, and the (future) shopping-list service.
All business logic stays in services per the repo's strict separation rule.

### 3.4 MCP server — agents as first-class clients

Expose FoodSavr's capabilities as tools over the Model Context Protocol so Claude,
Codex, or any MCP-capable agent can drive grocery management:

- **Transport**: streamable HTTP (remote MCP server, since FoodSavr data lives in
  Firebase behind user auth; stdio is unsuitable for a multi-user service).
- **Auth**: OAuth 2.1 authorization-code flow per MCP spec; reuse the same Firebase
  Auth identity — an MCP session maps to the end user's account, respecting
  Firestore security rules.
- **Tool surface (initial)**:
  - `list_inventory`, `get_product`
  - `ingest_receipt(text|image|store_ref)` — runs the universal normalization pipeline
  - `read_orders(source)` — e.g., Pizzabakeren order history → `LineItem`s
  - `generate_shopping_list` — inventory + meal-plan diff → list
  - `manage_shopping_list` (add/check/remove items)
  - `search_products(query)` — local + Open Food Facts
- **Resources**: shopping lists, inventory snapshots, meal plans as readable
  resources; provider connections as discoverable config.
- **Placement**: a Dart backend (shelf/dart_frog) or Firebase Functions host reusing
  the same models/normalization code via a shared package — avoids duplicating
  interpretation logic between the app and the MCP server. The Flutter app stays the
  reference UI; MCP is a protocol adapter, in keeping with the "adapter not
  duplicate" principle.
- **Licensing note**: MCP access falls under the same free-for-non-commercial terms.

## 4. Architecture Implications

1. **Extract a shared `foodsavr_core` package** (models, normalization, matching,
   shelf-life, provider contracts) consumed by: the Flutter app, the MCP server,
   and future scripts. Prevents logic drift between interfaces.
2. **Finish the domain layer first**: shopping lists, meal plans, recipes, users —
   these are prerequisites for meaningful list generation and for most MCP tools.
3. **Formalize the ingestion contract**: extend `IImportService` to return
   `List<NormalizedLineItem>`; make `Receipt`/`LineItem` first-class models
   alongside `Product`.
4. **Provider registry**: replace per-client wiring with declarative provider
   descriptors; add Pizzabakeren-style "order reader" providers as a new provider
   category (order sources vs. loyalty/receipt sources vs. identity sources).
5. **Confidence-based UX**: normalization results carry a confidence score;
   high-confidence ingest silently, low-confidence asks one question.
6. **Server-side sync**: move polling of private grocery APIs off-device
   (Cloud Functions / scheduler) — better for token security, rate limits, and
   for MCP agents acting on the user's behalf.

## 5. Success Criteria

- A user connects Rema (or scans a receipt, or forwards a Pizzabakeren order) and
  their inventory updates with zero manual entry.
- A grocery list exists and is correct after a meal plan is set — no manual curation.
- A Claude/Codex user can, through MCP alone, ingest a receipt and manage the
  resulting shopping list.
- No duplication of upstream data we don't own; FoodSavr stores only what it
  interprets and the user's own inventory/list state.
- Free for non-commercial use; sustainable operational footprint (Firebase
  managed services, per repo's "outsource when possible" principle).

## 6. Open Questions

- Storebox RDA requires a commercial agreement — does that fit the free-for-
  non-commercial model, or is BYOC the long-term answer?
- Should the MCP server be in-repo (monorepo `server/` dir) or a sibling repo
  consuming a published `foodsavr_core`?
- Vipps login (Norwegian market) — priority relative to agent/MCP work?
- Order-reading for restaurants like Pizzabakeren: email parsing (user forwards
  confirmation), receipt-file upload, or direct app-order integration first?
