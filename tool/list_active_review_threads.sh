#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <pr-number> [owner/repo]"
  exit 1
fi

PR_NUMBER="$1"
REPO="${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
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
              url
              path
            }
          }
        }
      }
    }
  }
}'

gh api graphql -f query="$QUERY" -F owner="$OWNER" -F repo="$NAME" -F num="$PR_NUMBER" \
  -q '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .isOutdated == false) | "\(.id) \(.comments.nodes[0].path) \(.comments.nodes[0].url)"' \
  | head -n 1
