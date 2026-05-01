#!/usr/bin/env bash
# resolve_review_threads_base.sh
# Usage: $0 <outdated|active|all> <pr-number> [owner/repo]
# Resolves ALL unresolved threads matching the given mode (not just the first).
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <outdated|active|all> <pr-number> [owner/repo]"
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
  all)
    JQ_FILTER='.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .id'
    LABEL='all unresolved'
    ;;
  *)
    echo "Invalid mode: $MODE. Expected one of: outdated, active, all"
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

mapfile -t thread_ids < <(
  gh api graphql -f query="$QUERY" -F owner="$OWNER" -F repo="$NAME" -F num="$PR_NUMBER" \
    -q "$JQ_FILTER"
)

if [[ ${#thread_ids[@]} -eq 0 ]]; then
  echo "No unresolved ${LABEL} threads found."
  exit 0
fi

count=0
for thread_id in "${thread_ids[@]}"; do
  [[ -z "$thread_id" ]] && continue
  gh api graphql -f query="$MUTATION" -F id="$thread_id" >/dev/null
  echo "Resolved: $thread_id"
  (( count++ )) || true
done
echo "Done — resolved ${count} ${LABEL} thread(s)."
