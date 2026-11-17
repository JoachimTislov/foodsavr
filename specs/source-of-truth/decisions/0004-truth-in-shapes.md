# ADR 0004: Truth expressed in shapes matched to intent

## Status

Accepted (explicit owner intent, recorded on #213)

## Context

ADR 0001–0003 established a Markdown source of truth, intent-gated spec additions, and autonomous execution. But prose alone is a weak sync medium: agents must re-derive structure from English sentences, and drift hides in ambiguity. Inspiration: HumanLayer's "frequent intentional compaction" — structured artifacts as the source of truth, prose only for the why.

## Decision

The source of truth is **not limited to text**. Each domain is expressed in the shape that matches its intent and is easiest to sync with the code:

| Domain | Shape | Path |
|---|---|---|
| Data model | JSON Schema | `schemas/line-item.schema.json`, `schemas/product.schema.json`, `schemas/collection.schema.json` |
| Service/integration surface | YAML registry | `registries/services.yaml` |
| Ingestion pipeline | Mermaid graph + table | inline in `ingestion-pipeline.md` |
| CI verification loop | Executable invariants | `scripts/ci/select_tests.dart` + `run_tests.dart` (already the truth) |
| MCP contract | Tool manifest | `contracts/mcp-tools.yaml` |
| Status/ledger | Table (already structured) | `status.md` |

Rules:

1. **Shape-first**: where a structured artifact exists, it is authoritative; the Markdown prose explains intent and links to it. Prose and shape must not duplicate a claim in divergent words — prose points at the shape.
2. **Syncable, not generated**: shapes are hand-maintained spec (like the rest of this folder), but each shape declares its code anchor (file paths) so a sync session can mechanically compare shape vs code.
3. **New shapes are intent-gated** like all spec additions (ADR 0002). The set above is approved by this ADR.
4. Sync sessions update shapes with the same rules as prose: fix truth value, add nothing conceptual.

## Consequences

- Agents gain mechanical drift checks (schema field vs Dart class field) instead of prose re-reading.
- `schemas/`, `registries/`, `contracts/` join `docs/source-of-truth/` and the sync loop's domain scope.
- Markdown remains the human-readable entrypoint; no information exists only in a shape without a linking doc.
