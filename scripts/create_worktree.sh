#!/usr/bin/env bash
set -euo pipefail

# scripts/create_worktree.sh
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
    if ! git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" && ! git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
        CREATE_BRANCH=true
    fi
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
SOURCE_DIR=$(git rev-parse --show-toplevel)
MAIN_DIR=$(git worktree list --porcelain | sed -n '1s/^worktree //p')

LINK_MAP=(
    ".gemini/policies:$HOME/.gemini/policies"
    ".env:$MAIN_DIR/.env"
    "assets/.env:$MAIN_DIR/assets/.env"
    "firebase.json:$MAIN_DIR/firebase.json"
    ".firebaserc:$MAIN_DIR/.firebaserc"
    "firestore.rules:$MAIN_DIR/firestore.rules"
    "firestore.indexes.json:$MAIN_DIR/firestore.indexes.json"
    "storage.rules:$MAIN_DIR/storage.rules"
    "android/app/google-services.json:$MAIN_DIR/android/app/google-services.json"
    "ios/Runner/GoogleService-Info.plist:$MAIN_DIR/ios/Runner/GoogleService-Info.plist"
    "macos/Runner/GoogleService-Info.plist:$MAIN_DIR/macos/Runner/GoogleService-Info.plist"
    "lib/firebase_options.dart:$MAIN_DIR/lib/firebase_options.dart"
)

usable_firebase_options() {
    grep -q 'class DefaultFirebaseOptions' "$1" 2>/dev/null &&
        ! grep -q 'Compile-only stub written by scripts/ci/local_ci.py' "$1"
}

for entry in "${LINK_MAP[@]}"; do
    DEST_REL="${entry%%:*}"
    SRC="${entry#*:}"
    DEST="$TARGET_DIR/$DEST_REL"
    if [[ -e "$DEST" || -L "$DEST" ]] ||
        ! git -C "$TARGET_DIR" check-ignore -q -- "$DEST_REL"; then
        continue
    fi
    if [[ "$SRC" == "$MAIN_DIR/"* && "$DEST_REL" == "lib/firebase_options.dart" ]] &&
        ! usable_firebase_options "$SRC"; then
        SRC="$SOURCE_DIR/$DEST_REL"
        if ! usable_firebase_options "$SRC"; then
            echo "  Skipped: $DEST_REL (no usable local Firebase options)"
            continue
        fi
    elif [[ "$SRC" == "$MAIN_DIR/"* && ! -e "$SRC" ]]; then
        SRC="$SOURCE_DIR/$DEST_REL"
    fi
    if [[ -e "$SRC" ]]; then
        mkdir -p "$(dirname "$DEST")"
        ln -s "$SRC" "$DEST"
        echo "  Symlinked: $DEST_REL"
    else
        echo "  Skipped: $DEST_REL (not found)"
    fi
done

echo "Fetching dependencies in new worktree..."
FLUTTER_BIN=$(python3 "$SOURCE_DIR/scripts/ci/local_ci.py" --flutter-bin)
cd "$TARGET_DIR" || exit 1
"$FLUTTER_BIN" pub get
git checkout -- analysis_options.yaml pubspec.lock 2>/dev/null || true

echo "Worktree ready at $TARGET_DIR"

if [[ -n "$TASK_DESC" ]]; then
    echo "Starting background agent in worktree with task: $TASK_DESC"
    gemini -p "$TASK_DESC" &
else
    echo "To start an agent in this worktree manually, run:"
    echo "   cd \"$TARGET_DIR\" && gemini -p \"your task description\" &"
fi
