#!/usr/bin/env bash
# resolve_thread_by_id.sh
# Resolves one or more PR review threads by their node IDs.
# Usage: $0 <thread-id> [thread-id ...]
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <thread-id> [thread-id ...]"
  echo "  thread-id: GraphQL node ID of the review thread (e.g. PRRT_kwDO...)"
  exit 1
fi

MUTATION='mutation($id:ID!){
  resolveReviewThread(input:{threadId:$id}){
    thread{ id isResolved }
  }
}'

count=0
for thread_id in "$@"; do
  result=$(gh api graphql -f query="$MUTATION" -F id="$thread_id")
  is_resolved=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['resolveReviewThread']['thread']['isResolved'])" 2>/dev/null || echo "unknown")
  echo "Resolved $thread_id (isResolved=$is_resolved)"
  (( count++ )) || true
done
echo "Done — resolved ${count} thread(s)."
