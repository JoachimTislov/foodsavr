#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <reviewer-username> [pr-number]"
  echo "If pr-number is omitted, uses the PR for the current branch."
  exit 1
fi

REVIEWER="$1"

if [[ $# -ge 2 ]]; then
  PR_NUMBER="$2"
else
  PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || true)
  if [[ -z "$PR_NUMBER" ]]; then
    echo "Could not determine PR for current branch. Please provide PR number."
    exit 1
  fi
fi

echo "Marking PR #$PR_NUMBER as ready for review..."
gh pr ready "$PR_NUMBER" 2>/dev/null || echo "PR is already ready for review or not a draft."

echo "Requesting review from $REVIEWER..."
gh pr edit "$PR_NUMBER" --add-reviewer "$REVIEWER"

echo "Done."
