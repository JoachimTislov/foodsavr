# Hot-file registry

Files that several lanes tend to touch, and how a batch splits them. Updated by step 8 of the queue planner after each batch; the last update names its source batch.

Last updated: batch 1 observations (2026-11-22), recorded while planning batch 2; agent logs are no longer hot (#397).

To refresh the candidate list, count recent touches on `develop`:

```sh
git log --since=60.days --name-only --format= origin/develop | grep -v '^$' | sort | uniq -c | sort -rn | head -30
```

The count finds files; the conventions below are what the history does not show.

## Seams with a convention

| Seam | Convention |
|---|---|
| `assets/translations/en.json`, `nb.json` | Each lane owns one namespace slot: a new top-level namespace or a new sub-object inside an existing one, inserted at a named **anchor** (directly after a named block). Anchors sit at least 7 lines from every other lane's anchor and every locked hunk, so rebases never touch adjacent lines. Same anchor in every locale; `make check` runs the locale check. |
| `lib/register_module.dart`, `lib/main.dart` (DI and startup) | One owning lane per batch. Other lanes construct their objects where they are used, or wait. |
| `specs/source-of-truth/status.md`, `data-model.md`, `schemas/*.json`, `contracts/*` | One owning lane per file per batch. A shape change ships in the PR that changes the code (ADR 0004), so two lanes that change one schema are serialized, never parallel. |
| `pubspec.yaml`, `pubspec.lock` | One lane per batch adds or bumps dependencies. |
| `test/support/`, `test/helpers/` (shared fakes) | The lane that creates a fake owns it for the batch. Other lanes keep fakes local to their test file and move to the shared one after it merges. |
| `specs/source-of-truth/sync-ledger.jsonl` | Append-only. A rebase conflict keeps both sides in timestamp order; `python3 scripts/agents/check_logs.py` validates. |
| `.agents/events/`, `.agents/ledger.jsonl`, `.agents/sessions/index.jsonl` | Not hot (#397): every agent log record is its own event file, so lanes never share a log file. The two legacy files are frozen; a lane that appends to one is a defect. |

## Hot files without a seam

One lane per batch owns each file; a second lane needs a stack or the next batch. Regions are named by symbol in the lane table.

| File | Why it is hot |
|---|---|
| `lib/services/product_service.dart` | Every add, save, delete, expiry, and cache path. |
| `lib/repositories/product_repository.dart` | Id generation, writes, timestamps; batch 1 produced an identical hunk in two PRs (#365, #368). |
| `lib/models/product_model.dart` | Status, expiry math, serialization, presentation; planned changes in #325, #327, #328. |
| `lib/views/product_form_view.dart` | Add, edit, and prefill flows. |
| `lib/views/product_detail_view.dart`, `lib/widgets/product/*` | Actions and status display. |
| `lib/services/firebase_auth_service.dart` | Sign-in, sign-up, sign-out, deletion; #330, #334, #354 all change it. |
| `lib/services/collection_service.dart` | Defaults, deletion, membership. |
| `lib/services/receipt_ingestion_service.dart` | Receipt placement, expiry, metadata. |
| `.github/workflows/ci-checks.yml`, `scripts/ci/*`, `make/*.mk` | CI selection and test running; #305 and #366 both change them. |
| `scripts/agents/agentctl.py`, `scripts/agents/test_agentctl.py` | The most-changed files in the repository. |

## Environment gotchas for lane briefs

- CI pins a Flutter version newer than the local default. Run checks with the pinned SDK (`~/flutter-3.47.6/bin` first on `PATH`) or results diverge from CI.
- Firestore rules are not tracked; rule changes ship as an owner action (`FIRESTORE_RULES_B64`), stated in the PR body.
- The label workflow strips `area/` and `risk/` labels from issues until #319 lands; lanes do not re-add them.
- A pre-push or `make push` failure in an unrelated area is a blocker to report with its output; push stays blocked rather than bypassed.
