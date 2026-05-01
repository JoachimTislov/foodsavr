#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <issue-number>"
  exit 1
fi

ISSUE_NUM="$1"
# Fetch issue title
TITLE=$(gh issue view "$ISSUE_NUM" --json title -q .title)
if [[ -z "$TITLE" ]]; then
  echo "Could not fetch issue #$ISSUE_NUM"
  exit 1
fi

# Sanitize title for branch name (lowercase, replace spaces/special chars with hyphens)
BRANCH_NAME=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g')
BRANCH_NAME="issue-${ISSUE_NUM}-${BRANCH_NAME}"

echo "Creating and checking out branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

echo "Branch $BRANCH_NAME created and tracking issue #$ISSUE_NUM."
