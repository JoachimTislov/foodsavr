# Issue tracker and domain docs

Repository configuration read by the tracker-aware skills (`issue-creator`, `to-spec`, `to-tickets`, `triage`, `wayfinder`, `queue-planner`, `implement`, `code-review`). It replaces per-skill setup.

## Issue tracker

GitHub Issues for this repository, through the `gh` CLI; `gh` infers the repo from the clone. Write multi-line bodies to a temporary file and pass `--body-file`. "Publish to the tracker" means create an issue; "fetch the ticket" means read it.

- **Read**: `gh issue view <n> --json number,title,body,labels,comments`. GitHub shares one number space: resolve a bare `#42` with `gh pr view 42`, falling back to `gh issue view 42`.
- **List**: `gh issue list --state open --json number,title,labels` with `--label`/`--search` filters.
- **Sub-issue**: `gh issue create --parent <parent> ...` or `gh issue edit <parent> --add-sub-issue <child>`; without sub-issues, start the child body with `Part of #<parent>`.
- **Blocking**: native dependencies, `gh issue create --blocked-by <n>,<n>` or `gh issue edit <child> --add-blocked-by <blocker>`; fallback, a `Blocked by: #<n>` line at the top of the body. Open blockers: `gh api repos/{owner}/{repo}/issues/<n> --jq .issue_dependencies_summary.blocked_by` (0 means startable).
- **Comment / label / close**: `gh issue comment`, `gh issue edit --add-label|--remove-label`; to close, comment first, then `gh issue close <n>`.

External pull requests are not a triage request surface.

## Wayfinding operations

Used by `wayfinder`. The **map** is one issue labelled `wayfinder:map`; its tickets are sub-issues labelled `wayfinder:<research|prototype|grilling|task>`.

- **Frontier**: the map's open sub-issues with no open blocker and no assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first write.
- **Resolve**: comment the answer, close the ticket, then append a gist and link to the map's Decisions-so-far.

## Queue operations

Used by `queue-planner`. A **batch** is one issue titled `Queue: batch N - <theme>` and labelled `queue:batch` (unmanaged, created on first use); its body holds the lanes table, integration order, owner actions, and deferred issues. Lane issues keep their epic parents and are linked from the table, never re-parented. The open `queue:batch` issue is the current batch; its closing retro feeds the next.

## Labels

Managed classification labels (`type/`, `area/`, `status/ci-*`, `risk/`) come from [.agents/github/labels.json](github/labels.json) and are applied by the label workflow; never hand-create them.

Triage state labels use the unmanaged `triage/` prefix, created on first use with `gh label create`:

| Canonical role | Label |
|---|---|
| category `bug` | `type/bug` |
| category `enhancement` | `type/feature` |
| `needs-triage` | `triage/needs-triage` |
| `needs-info` | `triage/needs-info` |
| `ready-for-agent` | `triage/ready-for-agent` |
| `ready-for-human` | `triage/ready-for-human` |
| `wontfix` | close the issue as not planned |

`triage/ready-for-agent` marks an issue a headless runner may pick up. When the owner applies it, `.github/workflows/agent-implement.yml` runs the `implement-issue` workflow and opens a draft PR; locally or in T3 Code, run the same workflow (see [.agents/workflows/README.md](workflows/README.md#implementing-issues)).

## Domain docs

Single context. The canonical spec is [specs/](../specs/INDEX.md); ADRs live in [specs/decisions/](../specs/decisions/) as `NNNN-slug.md`. The domain glossary is `specs/glossary.md`; create it, or any new spec section, only with explicit owner intent (ADR 0002).
