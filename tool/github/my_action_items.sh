#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "🎯  MY ACTION ITEMS"
echo "========================================"
echo ""

echo "📌 Issues Assigned to Me:"
gh issue list --assignee "@me" --state open --limit 10
echo ""

echo "👀 PRs Needing My Review:"
gh pr list --search "review-requested:@me state:open" --limit 10
echo ""

echo "🚀 My Open PRs:"
gh pr list --author "@me" --state open --limit 10
echo ""
echo "========================================"
