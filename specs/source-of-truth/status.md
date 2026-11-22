# Status & Sync Ledger

Built vs spec'd vs unbuilt, per domain. The sync loop (#213) claims un-synced domains here, audits them, and marks them verified. Spec-ahead items are contracts, not drift.

| Domain | State | Built | Spec-ahead |
|---|---|---|---|
| architecture | synced | layered Flutter/Firebase app, controller layer, DI | universal pipeline → agent → MCP server; hybrid event log + CRUD with Dart worker (ADR 0005) |
| data-model | synced | `products`, `collections`, models, LineItem in foodsavr_core | lists, meal plans, recipes, groups, offline sync; inbox, domain events, projections (ADR 0005) |
| ingestion-pipeline | synced | receipt/barcode/expiry services, pipeline skeleton (#202) | unify paths through pipeline (#192), confirmation UI (#193) |
| integrations | synced | Rema client, receipts, ML Kit, OFF enrichment | Coop (#194), Trumf/Storebox, orders, recipes, free text |
| mcp-server | synced | foodsavr_core skeleton | MCP server + Go API (#171) |
| qa-testing | synced | unit/integration tests, validation gates | eval setup (#166, #168) |
| ci-workflows | synced | ci-checks, builds, validation, manual Drive APK workflow, emulator visual artifacts, documentation Pages, merge gate, local CI mirror | Ubuntu 26 migration remainder; first live Drive test awaits secrets and verification |
| docs-status | synced | README/INDEX/TODO reconciled (#201) | this folder becomes authoritative; reconcile pointers |
| deployment-levels | synced | manifest + schema, `foodsavr_deploy` CLI (validate/plan/poll/env), Firebase scalers, Spark level (live) + Blaze level (Terraform `level`, budget; not yet applied), production + development (emulator) environments, bootstrap script, recommend-only workflow | Supabase/hybrid/standalone levels, app backend port, `test`/`staging` app flavors, gated promote executor (ADR 0005 phases 2-4) |

## Sync ledger

Replay records live in [sync-ledger.jsonl](sync-ledger.jsonl). Record session IDs,
issues, PRs, commit SHAs, audited domains, and results; link to git history.
