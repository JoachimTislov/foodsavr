#!/bin/bash
# tool/create_worktree.sh
# Creates a Git worktree for a specific branch and copies essential local-only files.

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <branch-name> [worktree-path]"
    exit 1
fi

BRANCH=$1
TARGET_DIR=${2:-"worktrees/$BRANCH"}

echo "🚀 Creating worktree for branch '$BRANCH' at '$TARGET_DIR'..."

# Create worktree
git worktree add "$TARGET_DIR" "$BRANCH"

# Copy essential local/generated files
echo "📦 Syncing essential environment files..."
cp .env "$TARGET_DIR/" 2>/dev/null || echo "⚠️  No .env found"
cp lib/firebase_options.dart "$TARGET_DIR/lib/" 2>/dev/null || echo "⚠️  No firebase_options.dart found"

# Optional: Run pub get in the new worktree
echo "📥 Fetching dependencies in new worktree..."
cd "$TARGET_DIR" && flutter pub get

echo "✨ Worktree ready at $TARGET_DIR"
