#!/usr/bin/env bash
# Sets skip=true when HEAD (a push to a release branch) already succeeded for
# this commit SHA, or has the exact tree of a merged PR's head commit on which
# workflow $1 already succeeded. Rebase merges rewrite SHAs but keep the tree
# when the PR was up to date, and fast-forward promotions preserve the SHA.
# Pull request synchronize events (typically a rebase onto a moved base) also skip
# when the previous head has a green run of the workflow and the tree diff old head
# -> new head touches nothing in the workflow's scope (the pathspecs).
# Usage: already_tested.sh <workflow-file.yml> [pathspec...]   (needs GH_TOKEN)
set -euo pipefail
out="${GITHUB_OUTPUT:-/dev/stdout}"
skip() { echo "skip=$1" >> "$out"; echo "already_tested: skip=$1 ($2)" >&2; exit 0; }

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
sha="${GITHUB_SHA:?}"

same_sha_ok=$(gh run list --repo "$repo" --workflow "$1" --commit "$sha" --status success --json databaseId --jq length 2>/dev/null || echo 0)
if [ "${same_sha_ok:-0}" -gt 0 ]; then
  skip true "workflow $1 already succeeded on commit $sha"
fi

pr=$(gh api "repos/$repo/commits/$sha/pulls" --jq '[.[]|select(.merged_at!=null)][0].number // empty') || skip false "PR lookup failed"
[ -n "$pr" ] || skip false "no merged PR for commit"
head=$(gh api "repos/$repo/pulls/$pr" --jq .head.sha)

git fetch --no-tags --depth=1 origin "$head" 2>/dev/null || skip false "cannot fetch PR head"
[ "$(git rev-parse "$sha^{tree}")" = "$(git rev-parse "$head^{tree}")" ] || skip false "tree differs from PR head (not up to date)"

ok=$(gh run list --repo "$repo" --workflow "$1" --commit "$head" --event pull_request --status success --json databaseId --jq length)
[ "${ok:-0}" -gt 0 ] || skip false "no successful PR run of $1 on $head"
skip true "tree identical to PR #$pr head $head, green $1"
