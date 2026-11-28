# Status & Sync Ledger

Built vs spec'd vs unbuilt, per domain. The sync loop (#213) claims un-synced domains here, audits them, and marks them verified. Spec-ahead items are contracts, not drift.

| Domain | State | Built | Spec-ahead |
|---|---|---|---|
| architecture | synced | layered Flutter/Firebase app, controller layer, DI | universal pipeline → agent → MCP server; hybrid event log + CRUD with Dart worker (ADR 0005); feature modules, plans and entitlements (ADR 0008) |
| data-model | synced | `products`, `collections`, `users/{uid}/settings/preferences`, models, LineItem in foodsavr_core, offline-first Firestore and queued barcode lookups (#348) | lists, meal plans, recipes, groups, offline conflict handling; inbox (transition phase: client writes first, #322), domain events, projections (ADR 0005); entitlement state, legal acceptance, age declaration and guardian consent records (ADR 0008, ADR 0009) |
| ingestion-pipeline | synced | receipt/barcode/expiry services, pipeline skeleton (#202) | unify paths through pipeline (#192), confirmation UI (#193) |
| integrations | synced | Rema client, receipts, ML Kit, OFF enrichment | Coop (#194), Trumf/Storebox, orders, recipes, free text |
| mcp-server | synced | foodsavr_core skeleton | MCP server + Go API (#171) |
| qa-testing | synced | unit/integration tests, validation gates | eval setup (#166, #168) |
| ci-workflows | synced | six workflows (#496): pull-request (checks, validation), merge-gate, release (promote, builds, hosting, Pages), agent-ops, ops-maintenance, manual-tools (Drive APK); emulator visual artifacts, local CI mirror | Ubuntu 26 migration remainder; first live Drive test awaits secrets and verification |
| agent-system | synced | agentctl workflows/routing/skills/sessions, agent-ops.yml (implement, review), adaptive review history & bisect learner, trusted-author merge gate (#303) | live runner alerts (#256), autonomous PR remediation loop (#303), trailer ruleset check (#277), GCS transcripts (#278) |
| docs-status | synced | README/INDEX/TODO reconciled (#201); human entry point `doc/humans.md` covers manual processes only (ADR 0011) | this folder becomes authoritative; reconcile pointers; generated system overview (ADR 0011) |
| deployment-levels | synced | manifest + schema, `foodsavr_deploy` CLI (validate/plan/poll/env), Firebase scalers, Spark level (live) + Blaze level (Terraform `level`, budget; not yet applied), test (develop, daily, weekly Hosting sites) + production (separate project, provisioned by `make setup`) + development (emulator) environments, per-environment Firebase options, bootstrap script, recommend-only workflow | Supabase/hybrid/standalone levels, app backend port, `test`/`staging` app flavors, gated promote executor (ADR 0005 phases 2-4); legal document sets per environment (ADR 0009) |
| user-stories | proposed | email and social sign-in, inventory and shopping-list CRUD, dashboard shell, settings, mobile-first web layout | no-default provisioning with kickstarters; dashboard home with inventory/shopping sections, insights and breadcrumbs (no task bar); scan-first ingestion and a many-imports matrix; export section with platform-appropriate steps; consistent spacing/sizing; social-auth settings; cross-browser PWA; LettMat brand (#532). Built: signed-out landing page with guest entry (design in `design/landing/`), dashboard insights, breadcrumb navigation, profile/settings split, batch expiry, receipt list, web barcode scanning |

## Sync ledger

Replay records live in [sync-ledger.jsonl](sync-ledger.jsonl). Record session IDs,
issues, PRs, commit SHAs, audited domains, and results; link to git history.
