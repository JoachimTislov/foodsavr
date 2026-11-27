# ADR 0002: Intent-gated spec changes and optimized verification loop

## Status

Accepted (explicit owner intent, recorded on #213)

## Context

1. The source of truth (#212, this folder) is kept aligned by sync sessions (#213), which are not allowed to add new concepts. Adding *new* specs must therefore be an explicit, owner-initiated act agreed before edits.
2. CI runs the full test suite on every change. The suite is fast today, but the intent is a system that grows; the verification loop must stay effective at catching **core bugs that are costly** (broken login, receipt scanning, inventory sync) while minimizing total suite runtime.

## Decision

### Spec changes are intent-gated

New specs, sections, or concepts are added only on explicit owner intent, and the change is agreed with the owner before edits land. Sync sessions may correct existing statements' truth value only.

### Optimized verification loop

The system shall behave as the intended usage induces: verification applies tests against the **main entry points and core parts** of the system.

1. **Hash-based caching.** Each test's inputs (its own file plus transitively imported app/lib sources) are hashed; when a run's hash matches a previously green run, that test is skipped as cached-green.
2. **Relational selection.** A relational construct maps changed files → the tests that import (directly or transitively) relate to them, so a change runs only the related slice of the suite.
3. **Core workflow pinning.** Tests covering core user workflows — **login**, **receipt scanning**, **inventory synchronization**, plus model/domain invariants — always run on CI triggers regardless of caching or selection, because a regression there is the costliest.
4. **Escape hatch.** A full-suite run is available at any time (`workflow_dispatch`, or label/comment) and is the fallback whenever the selection machinery itself is modified.

## Consequences

- CI runtime scales with the change surface, not the suite size.
- Core workflow regressions are caught on every trigger even when the change appears unrelated.
- The selection script (`scripts/ci/select_tests.dart`) and its relation map become covered scope: changes to them force a full run.
