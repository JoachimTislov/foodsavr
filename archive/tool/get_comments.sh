#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: get_comments.sh
# Description: Fetches all review threads (comments) for a specific GitHub Pull Request
#              using the GitHub GraphQL API.
# Usage: ./get_comments.sh <owner> <repo> <pr_number>
# Example: ./get_comments.sh JoachimTislov foodsavr 59
# ==============================================================================

# Ensure the required number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <owner> <repo> <pr_number>" >&2
    exit 1
fi

OWNER=$1
REPO=$2
PR_NUM=$3

# GraphQL query to fetch pull request review threads, including their resolution 
# status, file path, line number, and the body of the comments.
QUERY='query($owner:String!,$repo:String!,$num:Int!,$endCursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$num){
      reviewThreads(first:100,after:$endCursor){
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes{
          id
          isResolved
          isOutdated
          path
          line
          comments(first:100){
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes{
              body
            }
          }
        }
      }
    }
  }
}'

# Execute the query using the GitHub CLI (gh)
gh api graphql --paginate -f query="$QUERY" -F owner="$OWNER" -F repo="$REPO" -F num="$PR_NUM"