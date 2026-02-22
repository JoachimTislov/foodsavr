#!/usr/bin/env bash
# list_review_threads.sh
# Lists PR review threads with their status and first comment summary.
# Usage: $0 <pr-number> [owner/repo] [--all|--active|--outdated|--resolved]
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <pr-number> [owner/repo] [--all|--active|--outdated|--resolved]"
  exit 1
fi

PR_NUMBER="$1"
REPO="${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")}"
FILTER="${3:---active}"

# Allow filter as second arg if it starts with --
if [[ "$REPO" == --* ]]; then
  FILTER="$REPO"
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

OWNER="${REPO%/*}"
NAME="${REPO#*/}"

QUERY='query($owner:String!,$repo:String!,$num:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$num){
      reviewThreads(first:100){
        nodes{
          id
          isResolved
          isOutdated
          comments(first:1){
            nodes{
              path
              line
              body
            }
          }
        }
      }
    }
  }
}'

case "$FILTER" in
  --all)      JQ_FILTER='.data.repository.pullRequest.reviewThreads.nodes[]' ;;
  --resolved) JQ_FILTER='.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == true)' ;;
  --outdated) JQ_FILTER='.data.repository.pullRequest.reviewThreads.nodes[] | select(.isOutdated == true and .isResolved == false)' ;;
  --active)   JQ_FILTER='.data.repository.pullRequest.reviewThreads.nodes[] | select(.isOutdated == false and .isResolved == false)' ;;
  *)
    echo "Unknown filter: $FILTER. Use --all, --active, --outdated, or --resolved."
    exit 1
    ;;
esac

gh api graphql -f query="$QUERY" -F owner="$OWNER" -F repo="$NAME" -F num="$PR_NUMBER" \
  --jq "${JQ_FILTER} | \"\(.id) resolved=\(.isResolved) outdated=\(.isOutdated) \(.comments.nodes[0].path // \"\"): \(.comments.nodes[0].body[:100] // \"\")\"" \
  | while IFS= read -r line; do echo "$line"; echo; done
