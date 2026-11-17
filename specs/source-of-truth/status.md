# Status & Sync Ledger

Built vs spec'd vs unbuilt, per domain. The sync loop (#213) claims un-synced domains here, audits them, and marks them verified. Spec-ahead items are contracts, not drift.

| Domain | State | Built | Spec-ahead |
|---|---|---|---|
| architecture | synced | layered Flutter/Firebase app, controller layer, DI | universal pipeline → agent → MCP server |
| data-model | synced | `products`, `collections`, models, LineItem in foodsavr_core | lists, meal plans, recipes, groups, offline sync |
| ingestion-pipeline | synced | receipt/barcode/expiry services, pipeline skeleton (#202) | unify paths through pipeline (#192), confirmation UI (#193) |
| integrations | synced | Rema client, receipts, ML Kit, OFF enrichment | Coop (#194), Trumf/Storebox, orders, recipes, free text |
| mcp-server | synced | foodsavr_core skeleton | MCP server + Go API (#171) |
| qa-testing | synced | unit/integration tests, validation gates | eval setup (#166, #168) |
| ci-workflows | synced | ci-checks, builds, validation, release-gated | Ubuntu 26 migration remainder |
| docs-status | synced | README/INDEX/TODO reconciled (#201) | this folder becomes authoritative; reconcile pointers |

## Sync ledger

Replay record per session. Store session ID, issue, PR, commit SHAs; forward to git history — never paste diffs here.

| Session | Issue | PR | Commits | Domains audited | Result |
|---|---|---|---|---|---|
| vibe-848bbd-bootstrap | #213 | (this PR) | 103a70f baseline | none (bootstrap absorb only) | folder created; all domains un-synced pending audit |
| vibe-848bbd-audit | #213 | #214 | head of vibe/source-of-truth-bootstrap-848bbd | all 8 domains | zero discrepancies; every spec claim verified read-only against code (collections, services, clients, core exports, workflows, tests); all domains marked synced |
| vibe-848bbd-verification | #213 | #215 | head of vibe/optimized-verification-loop-848bbd | ci-workflows, qa-testing | ADR 0002 + ADR 0003 implemented and CI-verified green (206 tests, 2m20s); 6 autonomous fix commits per ADR 0003 |
| vibe-848bbd-shapes | #213 | #215 | head of vibe/optimized-verification-loop-848bbd | data-model, integrations, mcp-server | ADR 0004: shapes (3 JSON Schemas, services registry, MCP contract) + check_shape_sync.dart validator wired into CI; verified locally (30 schema props, 14 anchors, shape-sync OK) |
