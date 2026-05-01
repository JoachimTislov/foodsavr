#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  # Try to get PR number for current branch
  PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || true)
  if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: $0 <pr-number>"
    echo "Or run from a branch with an active PR."
    exit 1
  fi
else
  PR_NUMBER="$1"
fi

echo "Updating PR #$PR_NUMBER with base branch..."
gh pr update-branch "$PR_NUMBER"
echo "Done."
