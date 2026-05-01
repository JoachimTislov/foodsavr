#!/usr/bin/env bash
set -euo pipefail

export GH_PAGER=cat

CACHE_FILE=".pr_comments_cache.json"
FORCE_FETCH=0

if [[ "${1:-}" == "--refresh" ]]; then
  FORCE_FETCH=1
  shift
fi

PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null)

if [[ ! -f "$CACHE_FILE" ]] || [[ "$FORCE_FETCH" == "1" ]]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
  OWNER="${REPO%/*}"
  NAME="${REPO#*/}"

  QUERY='query($owner:String!,$repo:String!,$num:Int!,$endCursor:String){
    repository(owner:$owner,name:$repo){
      pullRequest(number:$num){
        reviewThreads(first:100,after:$endCursor){
          pageInfo{
            hasNextPage
            endCursor
          }
          nodes{
            id
            isResolved
            comments(first:100){
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

  echo "Fetching active comments for PR #$PR_NUMBER and caching locally..."
  echo "--------------------------------------------------------"

  gh api graphql -f query="$QUERY" -F owner="$OWNER" -F repo="$NAME" -F num="$PR_NUMBER" > "$CACHE_FILE"
else
  echo "Reading active comments from local cache..."
  echo "--------------------------------------------------------"
fi

OUTPUT=$(jq -r '
  [ .data.repository.pullRequest.reviewThreads.nodes[]? // empty
  | select(.isResolved == false) ]
  | if length > 0 then
      .[0] | . as $thread | $thread.comments.nodes[0]
      | "Thread ID: \($thread.id)\nFile: \(.path):\(.line // "general")\n\nComment:\n\(.body)\n--------------------------------------------------------"
    else
      ""
    end
' "$CACHE_FILE")

if [[ -z "$OUTPUT" ]]; then
  echo "No active comments found."
  rm -f "$CACHE_FILE"
else
  echo "$OUTPUT"
fi
