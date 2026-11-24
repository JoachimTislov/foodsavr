#!/usr/bin/env bash
set -euo pipefail

# scripts/link_local_files.sh <target-dir> [source-dir]
# Symlinks ignored, local-only files (env, Firebase config) from the main checkout into a worktree.
# Shared by scripts/create_worktree.sh and scripts/git_bisect.py.

TARGET_DIR="${1:?Usage: $0 <target-dir> [source-dir]}"
SOURCE_DIR="${2:-$(git rev-parse --show-toplevel)}"
MAIN_DIR=$(git -C "$SOURCE_DIR" worktree list --porcelain | sed -n '1s/^worktree //p')

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
)

for entry in "${LINK_MAP[@]}"; do
    DEST_REL="${entry%%:*}"
    SRC="${entry#*:}"
    DEST="$TARGET_DIR/$DEST_REL"
    if [[ -e "$DEST" || -L "$DEST" ]] ||
        ! git -C "$TARGET_DIR" check-ignore -q -- "$DEST_REL"; then
        continue
    fi
    if [[ "$SRC" == "$MAIN_DIR/"* && ! -e "$SRC" ]]; then
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
