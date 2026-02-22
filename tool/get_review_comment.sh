#!/usr/bin/env bash
# get_review_comment.sh
# Fetches a single PR review comment by its numeric ID and prints path, line, and body.
# Usage: $0 <comment-id> [owner/repo]
#
# comment-id: the numeric ID from the GitHub URL fragment (e.g. r2837290495 → 2837290495)
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <comment-id> [owner/repo]"
  echo "  comment-id: numeric ID from the GitHub discussion URL (e.g. 2837290495)"
  exit 1
fi

COMMENT_ID="$1"
REPO="${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

gh api "repos/${REPO}/pulls/comments/${COMMENT_ID}" \
  --jq '"Path: \(.path)\nLine: \(.line // .original_line)\nOutdated: \(.outdated)\nBody:\n\(.body)"'
