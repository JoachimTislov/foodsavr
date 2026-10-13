# Status & Sync Ledger

Built vs spec'd vs unbuilt, per domain. The sync loop (#213) claims un-synced domains here, audits them, and marks them verified. Spec-ahead items are contracts, not drift.

| Domain | State | Built | Spec-ahead |
|---|---|---|---|
| architecture | un-synced | layered Flutter/Firebase app, controller layer, DI | universal pipeline → agent → MCP server |
| data-model | un-synced | `products`, `collections`, models, LineItem in foodsavr_core | lists, meal plans, recipes, groups, offline sync |
| ingestion-pipeline | un-synced | receipt/barcode/expiry services, pipeline skeleton (#202) | unify paths through pipeline (#192), confirmation UI (#193) |
| integrations | un-synced | Rema client, receipts, ML Kit, OFF enrichment | Coop (#194), Trumf/Storebox, orders, recipes, free text |
| mcp-server | un-synced | foodsavr_core skeleton | MCP server + Go API (#171) |
| qa-testing | un-synced | unit/integration tests, validation gates | eval setup (#166, #168) |
| ci-workflows | un-synced | ci-checks, builds, validation, release-gated | Ubuntu 26 migration remainder |
| docs-status | un-synced | README/INDEX/TODO reconciled (#201) | this folder becomes authoritative; reconcile pointers |

## Sync ledger

Replay record per session. Store session ID, issue, PR, commit SHAs; forward to git history — never paste diffs here.

| Session | Issue | PR | Commits | Domains audited | Result |
|---|---|---|---|---|---|
| vibe-848bbd-bootstrap | #213 | (this PR) | 103a70f baseline | all (bootstrap absorb) | folder created; all domains un-synced pending audit |
