#!/usr/bin/env bash
# Sets skip=true when HEAD (a push to main) has the exact tree of a merged PR's
# head commit on which workflow $1 already succeeded. Rebase merges rewrite
# SHAs but keep the tree when the PR was up to date, so the push run is redundant.
# Usage: already_tested.sh <workflow-file.yml>   (needs GH_TOKEN, full-enough checkout)
set -euo pipefail
out="${GITHUB_OUTPUT:-/dev/stdout}"
skip() { echo "skip=$1" >> "$out"; echo "already_tested: skip=$1 ($2)" >&2; exit 0; }

[ "${GITHUB_EVENT_NAME:-}" = "push" ] || skip false "not a push"
sha="${GITHUB_SHA:?}"; repo="${GITHUB_REPOSITORY:?}"

pr=$(gh api "repos/$repo/commits/$sha/pulls" --jq '[.[]|select(.merged_at!=null)][0].number // empty') || skip false "PR lookup failed"
[ -n "$pr" ] || skip false "no merged PR for commit"
head=$(gh api "repos/$repo/pulls/$pr" --jq .head.sha)

git fetch --no-tags --depth=1 origin "$head" 2>/dev/null || skip false "cannot fetch PR head"
[ "$(git rev-parse "$sha^{tree}")" = "$(git rev-parse "$head^{tree}")" ] || skip false "tree differs from PR head (not up to date)"

ok=$(gh run list --repo "$repo" --workflow "$1" --commit "$head" --event pull_request --status success --json databaseId --jq length)
[ "${ok:-0}" -gt 0 ] || skip false "no successful PR run of $1 on $head"
skip true "tree identical to PR #$pr head $head, green $1"
