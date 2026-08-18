#!/usr/bin/env sh
# Symlink the phoenix-design-sync skill into ~/.claude/skills so it is
# available in every Claude Code session. Re-run after moving this repo.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC="$REPO_DIR/skills/phoenix-design-sync"
DEST="$HOME/.claude/skills/phoenix-design-sync"

[ -d "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }
mkdir -p "$HOME/.claude/skills"

if [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
  echo "error: $DEST exists and is not a symlink — remove it first" >&2
  exit 1
fi

ln -sfn "$SRC" "$DEST"
echo "installed: $DEST -> $SRC"
