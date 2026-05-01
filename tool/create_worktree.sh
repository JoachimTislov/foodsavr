#!/usr/bin/env bash
set -euo pipefail

# tool/create_worktree.sh
# Creates a Git worktree for a specific branch or issue and symlinks essential local-only files.

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <branch-name-or-issue-number> [worktree-path] [task-description]"
    exit 1
fi

INPUT="$1"
TARGET_DIR="${2:-}"
TASK_DESC="${3:-}"

BRANCH_NAME=""
CREATE_BRANCH=false

# If input is exactly digits, treat it as an issue number
if [[ "$INPUT" =~ ^[0-9]+$ ]]; then
    ISSUE_NUM="$INPUT"
    echo "Fetching issue #$ISSUE_NUM..."
    TITLE=$(gh issue view "$ISSUE_NUM" --json title -q .title 2>/dev/null || echo "")
    if [[ -z "$TITLE" ]]; then
        echo "Could not fetch issue #$ISSUE_NUM"
        exit 1
    fi
    
    SANITIZED_TITLE=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g')
    BRANCH_NAME="issue-${ISSUE_NUM}-${SANITIZED_TITLE}"
    CREATE_BRANCH=true
else
    BRANCH_NAME="$INPUT"
    # Determine if branch exists locally or remotely
    if ! git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" && ! git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
        CREATE_BRANCH=true
    fi
fi

# Determine default target dir if not provided
if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR="../$BRANCH_NAME"
fi

echo "Creating worktree for branch '$BRANCH_NAME' at '$TARGET_DIR'..."

if [[ "$CREATE_BRANCH" == true ]]; then
    git worktree add -b "$BRANCH_NAME" "$TARGET_DIR"
else
    git worktree add "$TARGET_DIR" "$BRANCH_NAME"
fi

echo "Symlinking essential environment files..."
MAIN_DIR=$(git rev-parse --show-toplevel)

FILES_TO_SYMLINK=(
    ".env"
    "firebase.json"
    ".firebaserc"
    "firestore.rules"
    "firestore.indexes.json"
    "storage.rules"
    "android/app/google-services.json"
    "ios/Runner/GoogleService-Info.plist"
    "macos/Runner/GoogleService-Info.plist"
    "lib/firebase_options.dart"
)

for file in "${FILES_TO_SYMLINK[@]}"; do
    SRC="$MAIN_DIR/$file"
    DEST="$TARGET_DIR/$file"
    if [[ -e "$SRC" ]]; then
        mkdir -p "$(dirname "$DEST")"
        rm -f "$DEST"
        # Create absolute symlink
        ln -s "$SRC" "$DEST"
        echo "  Symlinked: $file"
    else
        echo "  Skipped: $file (not found in main tree)"
    fi
done

echo "Fetching dependencies in new worktree..."
cd "$TARGET_DIR" || exit 1
flutter pub get

echo "Worktree ready at $TARGET_DIR"

if [[ -n "$TASK_DESC" ]]; then
    echo "Starting background agent in worktree with task: $TASK_DESC"
    gemini -p "$TASK_DESC" &
else
    echo "To start an agent in this worktree manually, run:"
    echo "   cd \"$TARGET_DIR\" && gemini -p \"your task description\" &"
fi
