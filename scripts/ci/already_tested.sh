#!/usr/bin/env bash
# Sets skip=true when HEAD (a push to daily, weekly, or stable) already succeeded for
# this commit SHA, or has the exact tree of a merged PR's head commit on which
# workflow $1 already succeeded. Rebase merges rewrite SHAs but keep the tree
# when the PR was up to date, and fast-forward promotions preserve the SHA.
# Pull request synchronize events (typically a rebase onto a moved base) also skip
# when the previous head has a green run of the workflow and the tree diff old head
# -> new head touches nothing in the workflow's scope (the pathspecs).
# Usage: already_tested.sh [--push-only-reuse] <workflow-file.yml> [pathspec...]   (needs GH_TOKEN)
set -euo pipefail
out="${GITHUB_OUTPUT:-/dev/stdout}"
skip() { echo "skip=$1" >> "$out"; echo "already_tested: skip=$1 ($2)" >&2; exit 0; }

push_only_reuse=false
if [ "${1:-}" = "--push-only-reuse" ]; then
  push_only_reuse=true
  shift
fi

repo="${GITHUB_REPOSITORY:?}"
if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
  wf="$1"; shift
  [ "$(jq -r .action "$GITHUB_EVENT_PATH")" = "synchronize" ] || skip false "not a synchronize event"
  [ "$#" -gt 0 ] || skip false "no scope pathspecs given"
  before=$(jq -r .before "$GITHUB_EVENT_PATH"); new=$(jq -r .pull_request.head.sha "$GITHUB_EVENT_PATH")
  git fetch --no-tags --depth=1 origin "$before" "$new" 2>/dev/null || skip false "cannot fetch previous head"
  ok=$(gh run list --repo "$repo" --workflow "$wf" --commit "$before" --event pull_request --status success --json databaseId --jq length)
  [ "${ok:-0}" -gt 0 ] || skip false "no green $wf run on previous head $before"
  touched=$(git diff --name-only "$before" "$new" -- "$@") || skip false "diff failed"
  [ -z "$touched" ] || skip false "changes since previous head are in scope"
  skip true "previous head $before green; nothing in scope changed"
fi
[ "${GITHUB_EVENT_NAME:-}" = "push" ] || skip false "not a push"
wf="$1"; shift
sha="${GITHUB_SHA:?}"

# Helper: verify at least one matching workflow run executed non-skipped work
# (GitHub marks a workflow run conclusion=success even when every job was skipped).
has_non_skipped_run() {
  local commit_sha="$1"
  local event_filter="${2:-}"
  local args=(run list --repo "$repo" --workflow "$wf" --commit "$commit_sha" --status success --json databaseId --jq '.[].databaseId')
  if [ -n "$event_filter" ]; then
    args+=(--event "$event_filter")
  fi
  local run_ids
  run_ids=$(gh "${args[@]}" 2>/dev/null || true)
  local run_id
  for run_id in $run_ids; do
    local executed
    executed=$(gh api "repos/$repo/actions/runs/$run_id/jobs" \
      --jq '[.jobs[] | select(.conclusion == "success" and (.name | test("already|detect|skip|preflight|validation status"; "i") | not))] | length' 2>/dev/null || echo 0)
    if [ "${executed:-0}" -gt 0 ]; then
      return 0
    fi
  done
  return 1
}

if [ "$push_only_reuse" = "true" ]; then
  if has_non_skipped_run "$sha" push; then
    skip true "workflow $wf already succeeded on a push run for commit $sha"
  fi
  skip false "full push validation required on release branch for commit $sha"
fi

if has_non_skipped_run "$sha"; then
  skip true "workflow $wf already succeeded with executed jobs on commit $sha"
fi

# Guard against multi-PR fast-forward batches: if multiple commits were pushed
# and scope pathspecs are given, only allow PR-head tree reuse when the push
# contains a single commit or when the exact tree of HEAD was tested.
if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
  before=$(jq -r '.before // empty' "$GITHUB_EVENT_PATH" 2>/dev/null || true)
  commit_count=$(jq -r '(.commits // []) | length' "$GITHUB_EVENT_PATH" 2>/dev/null || echo 0)
  if [ -n "$before" ] && [ "$before" != "0000000000000000000000000000000000000000" ] && [ "${commit_count:-0}" -gt 1 ] && [ "$#" -gt 0 ]; then
    if git fetch --no-tags --depth=1 origin "$before" "$sha" 2>/dev/null; then
      touched=$(git diff --name-only "$before" "$sha" -- "$@" 2>/dev/null || echo "diff-failed")
      if [ -n "$touched" ]; then
        skip false "multi-commit push ($commit_count commits) touched in-scope paths"
      fi
    else
      skip false "multi-commit push ($commit_count commits) and cannot inspect before..sha diff"
    fi
  fi
fi

pr=$(gh api "repos/$repo/commits/$sha/pulls" --jq '[.[]|select(.merged_at!=null)][0].number // empty') || skip false "PR lookup failed"
[ -n "$pr" ] || skip false "no merged PR for commit"
head=$(gh api "repos/$repo/pulls/$pr" --jq .head.sha)

git fetch --no-tags --depth=1 origin "$head" 2>/dev/null || skip false "cannot fetch PR head"
[ "$(git rev-parse "$sha^{tree}")" = "$(git rev-parse "$head^{tree}")" ] || skip false "tree differs from PR head (not up to date)"

if ! has_non_skipped_run "$head" pull_request; then
  skip false "no successful non-skipped PR run of $wf on $head"
fi
skip true "tree identical to PR #$pr head $head, green $wf"
