# ADR 0011: Human docs cover manual processes only

## Status

Accepted (explicit owner intent, 2026-11-23: "Focus on only writing documentation for manual processes and leaving only scripts for fully automated sequences. The idea is to abstract away the framework that runs the show: AI is now capable of maintaining this system itself; a human may guide but shouldn't spend time reading much of its docs, since they drift; rather maintain a high-level representation of the system."). Refines the authority split of [ADR 0001](0001-source-of-truth-sync-loop.md) and [ADR 0004](0004-truth-in-shapes.md) for human-facing prose.

## Context

Human setup and operations prose (`doc/getting_started.md`, `doc/implementation/development-setup.md`, a documentation index) described sequences that `make setup`, `scripts/setup/setupctl.py`, and `scripts/infra/` now automate. Prose copies of automated sequences drift from the scripts, and agents maintain the system, so a human has no reason to read them.

## Decision

1. **Human docs cover manual processes and steering only.** The single human entry point is [doc/humans.md](../../../doc/humans.md): how to start, the complete list of manual processes with one command or script each, how to steer, and where to see live state. It names no framework internals.
2. **Automated sequences live only in scripts and make targets.** Prose does not restate them; it points at the command.
3. **Agent-facing knowledge lives in skills and `specs/source-of-truth/`.** Human-facing docs do not duplicate it.
4. **The high-level system representation is generated from manifests, not hand-written.** `make agent-status` (from `.agents/system.json`) is the current live view. A generated system overview is follow-up work.
5. Product vision and research docs are unaffected.

## Consequences

- A manual process without a script (for example enabling a Firebase sign-in provider) is listed in `doc/humans.md`; once automated it leaves the list.
- Docs that only restate automation are deleted; git history keeps them.
- Remaining detailed prose (`doc/implementation/`, `doc/plan/`, `INDEX.md`, `infra/terraform/README.md`) is design or reference material to be reduced by later sync sessions or replaced by generated views.
