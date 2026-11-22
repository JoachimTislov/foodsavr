#!/usr/bin/env bash
# Sync .agents/reviews/history.jsonl with the dedicated agent-review-history branch.
#
#   review_history.sh fetch [TOKEN]  overwrite the local file with the branch copy, if it exists
#   review_history.sh push [TOKEN]   append records missing on the branch, then push (retries on races)
#
# CI writes review and incident records to the branch, not to main, so the merge gate and
# the review classifier read data that PRs cannot edit (ADR 0006).
set -euo pipefail

BRANCH="${REVIEW_HISTORY_BRANCH:-agent-review-history}"
FILE=".agents/reviews/history.jsonl"
REMOTE="${REVIEW_HISTORY_REMOTE:-origin}"

auth_url() {
  local url token="$1"
  url="$(git remote get-url "$REMOTE")"
  if [ -n "$token" ]; then
    url="https://x-access-token:${token}@${url#https://}"
  fi
  printf '%s' "$url"
}

fetch() {
  if git fetch --depth=1 "$(auth_url "${1:-}")" "$BRANCH" 2>/dev/null; then
    mkdir -p "$(dirname "$FILE")"
    git show FETCH_HEAD:history.jsonl >"$FILE"
  fi
}

push() {
  local token="${1:-}" repo_dir work attempt url
  repo_dir="$(pwd)"
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  url="$(auth_url "$token")"
  for attempt in 1 2 3 4; do
    rm -rf "$work/repo"
    if git clone --quiet --depth=1 --branch "$BRANCH" "$url" "$work/repo" 2>/dev/null; then
      touch "$work/repo/history.jsonl"
    else
      git init --quiet "$work/repo"
      git -C "$work/repo" checkout --quiet -b "$BRANCH"
      git -C "$work/repo" remote add origin "$url"
      : >"$work/repo/history.jsonl"
    fi
    # Append only local records the branch lacks; keep the final newline invariant.
    if [ -s "$repo_dir/$FILE" ]; then
      [ -n "$(tail -c1 "$work/repo/history.jsonl")" ] && echo >>"$work/repo/history.jsonl"
      grep -v '^[[:space:]]*$' "$repo_dir/$FILE" | grep -vxFf "$work/repo/history.jsonl" >>"$work/repo/history.jsonl" || true
    fi
    git -C "$work/repo" add history.jsonl
    if git -C "$work/repo" diff --cached --quiet; then
      return 0
    fi
    git -C "$work/repo" -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
      commit --quiet -m "chore(agents): record review history"
    if git -C "$work/repo" push --quiet origin "HEAD:refs/heads/$BRANCH" 2>/dev/null; then
      return 0
    fi
    sleep $((attempt * 2))
  done
  echo "review_history: push failed after retries" >&2
  return 1
}

case "${1:-}" in
  fetch) fetch "${2:-}" ;;
  push) push "${2:-}" ;;
  *) echo "usage: $0 fetch [TOKEN] | push [TOKEN]" >&2; exit 2 ;;
esac
