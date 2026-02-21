#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <outdated|active> <pr-number> [owner/repo]"
  exit 1
fi

MODE="$1"
PR_NUMBER="$2"
REPO="${3:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
OWNER="${REPO%/*}"
NAME="${REPO#*/}"

case "$MODE" in
  outdated)
    JQ_FILTER='.data.repository.pullRequest.reviewThreads.nodes[] | select(.isOutdated == true and .isResolved == false) | .id'
    LABEL='outdated'
    ;;
  active)
    JQ_FILTER='.data.repository.pullRequest.reviewThreads.nodes[] | select(.isOutdated == false and .isResolved == false) | .id'
    LABEL='active'
    ;;
  *)
    echo "Invalid mode: $MODE. Expected one of: outdated, active"
    exit 1
    ;;
esac

QUERY='query($owner:String!,$repo:String!,$num:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$num){
      reviewThreads(first:100){
        nodes{
          id
          isResolved
          isOutdated
        }
      }
    }
  }
}'

MUTATION='mutation($id:ID!){
  resolveReviewThread(input:{threadId:$id}){
    thread{
      id
      isResolved
      isOutdated
    }
  }
}'

thread_id="$(
  gh api graphql -f query="$QUERY" -F owner="$OWNER" -F repo="$NAME" -F num="$PR_NUMBER" \
    -q "$JQ_FILTER" | head -n 1
)"

if [[ -z "${thread_id:-}" ]]; then
  echo "No unresolved ${LABEL} thread found."
  exit 0
fi

gh api graphql -f query="$MUTATION" -F id="$thread_id" >/dev/null
echo "Resolved ${LABEL} thread: $thread_id"
