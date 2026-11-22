# Queue issue and lane brief

## Queue issue

Title `Queue: batch N - <theme>`, label `queue:batch`, body:

```markdown
## Locks

In-flight PRs whose footprints are locked for this batch: #<pr> (<issue>), ...

## Lanes

| Lane | Issue | Branch | Base | Blocked by | Owns | Seam slots | Model / effort |
|---|---|---|---|---|---|---|---|
| L1 | #<n> <title> | `issue-<n>-<slug>` | `develop` | none | `path` (`Symbol`), ... | translations: `<namespace>` after `<block>` | <model> / <effort> |

Every lane leaves all other files alone; a needed change outside its footprint is reported, not made.

## Integration order

1. <in-flight PRs first, in dependency order>
2. L<k> (#<n>): <why here>

The merge gate merges the lowest-numbered ready `merge/auto` PR first; where this order differs, label one PR at a time.

## Owner actions

- [ ] <decision, rules deployment, secret, or label> - unblocks <issue or PR>

## Deferred

| Issue | Reason | Earliest batch |
|---|---|---|
| #<n> | <locked by #pr / needs decision #d / shares seam with L<k>> | N+1 |

## Retro

Filled in when the batch closes (queue-planner step 8).
```

## Lane brief

The brief each implementing agent receives. Fill every angle bracket; keep the rest verbatim.

```text
Implement lane L<k> of <queue issue URL>: issue #<n> "<title>" (<Closes or Part of> #<n>).
Load the `implement` skill and follow its one-ticket steps.

Worktree and branch: `make worktree name=issue-<n>-<slug>`, base `<base>`.
Footprint you own: <paths and symbols>.
Seam slots: <translation namespace and anchor, or none>.
Leave every other file alone. If the issue needs a change outside the footprint, stop that part and report it in the PR body.
<Stacked lanes only: Stacked on #<pr>; rebase onto it when it moves, retarget to develop after it merges.>

Before every push: `make check` green with CI's pinned Flutter on PATH; pre-push hook green.
Never `--no-verify`, never merge a base into the branch: rebase and `--force-with-lease`.
Commit with the `commit` skill; open a draft PR against `<base>` with the `pr` skill.
Do not add `merge/auto` or triage labels; the owner does.
An unrelated failing check is a blocker: record it in the PR body and the ledger, then stop.

Final line, exactly: PR <full URL>, head <SHA>, checks and reviews <state>
```
