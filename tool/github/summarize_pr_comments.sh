#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <pr-number>"
  exit 1
fi

PR_NUMBER="$1"
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
OWNER="${REPO%/*}"
NAME="${REPO#*/}"

QUERY='query($owner:String!,$repo:String!,$num:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$num){
      reviewThreads(first:50){
        nodes{
          isResolved
          comments(first:50){
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

echo "Fetching unresolved comments for PR #$PR_NUMBER..."
echo ""

gh api graphql -f query="$QUERY" -F owner="$OWNER" -F repo="$NAME" -F num="$PR_NUMBER" \
  -q '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .comments.nodes[] | "- [ ] `\(.path):\(.line // "general")` \(.body | gsub("\n"; " "))"'

echo ""
echo "Done."
