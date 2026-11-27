# FoodSavr Source of Truth

This folder is the canonical spec of FoodSavr (#212). Code and existing docs are absorbed here; the sync loop (#213) keeps it aligned with the code state. Agents: read [status.md](status.md) first, claim a domain, and follow the loop rules in #213.

## Reading order

1. [architecture.md](architecture.md) — system context and boundaries
2. [user-stories.md](user-stories.md) — user-intent spec: stories, kickstarters, imports/exports, platform behavior
3. [data-model.md](data-model.md) — LineItem and persistence
4. [ingestion-pipeline.md](ingestion-pipeline.md) — normalization to confidence gate
5. [integrations.md](integrations.md) — per-source ingestion contracts
6. [mcp-server.md](mcp-server.md) — remote MCP tools and shared package
7. [qa-testing.md](qa-testing.md) and [ci-workflows.md](ci-workflows.md) — quality gates
8. [deployment-levels.md](deployment-levels.md) — levels ladder, environments, triggers, bootstrap
9. [agent-system.md](agent-system.md) — using and managing the agent system, workflows, and PR integration
10. [status.md](status.md) — built vs spec'd vs unbuilt, and the session ledger
11. [decisions/](decisions/) — ADRs

Shaped artifacts (authoritative where they exist, per ADR 0004): [schemas/](schemas/) and [registries/](registries/services.yaml) — mechanically validated against code (registry anchors; schema properties vs anchored model fields, in both directions) by `scripts/ci/check_shape_sync.dart` in CI. [contracts/](contracts/mcp-tools.yaml) (MCP tools; raw/domain event schemas per ADR 0005; feature registry, entitlement and legal-document schemas per ADR 0008 and ADR 0009, with the spec-ahead catalog [registries/feature-modules.yaml](registries/feature-modules.yaml)) are spec-ahead and not validated by that checker.

## Authoritative vs derived

- Files in this folder are **authoritative** for what the system is and is spec'd to become.
- `README.md`, `INDEX.md` (root), `TODO.md`, and `doc/` are historical/entrypoint material; where they conflict with this folder, this folder wins and the conflict is a sync-loop finding.

## Update rules

See #213 (abstract sync loop). In short: contract-first — if the code is correct, the spec is updated; sync sessions write docs only and add no new concepts.
