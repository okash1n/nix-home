#!/usr/bin/env bash
# llm-agents input auto updater
set -euo pipefail

NIX_HOME_DIR="${NIX_HOME_DIR:-$HOME/nix-home}"
TARGET_BRANCH="${NIX_HOME_LLM_AGENTS_UPDATE_BRANCH:-main}"
STATE_DIR="${NIX_HOME_STATE_DIR:-$HOME/.local/state/nix-home}"
LOCK_DIR="$STATE_DIR/locks"
LOCK_PATH="$LOCK_DIR/llm-agents-auto-update.lock"

if [ -d "/run/current-system/sw/bin" ]; then
  PATH="/run/current-system/sw/bin:$PATH"
fi
if command -v id >/dev/null 2>&1; then
  CURRENT_USER="$(id -un 2>/dev/null || true)"
  if [ -n "$CURRENT_USER" ] && [ -d "/etc/profiles/per-user/$CURRENT_USER/bin" ]; then
    PATH="/etc/profiles/per-user/$CURRENT_USER/bin:$PATH"
  fi
fi
if [ -d "$HOME/.nix-profile/bin" ]; then
  PATH="$HOME/.nix-profile/bin:$PATH"
fi
export PATH

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*"
}

mkdir -p "$STATE_DIR" "$LOCK_DIR"

if ! mkdir "$LOCK_PATH" >/dev/null 2>&1; then
  log "[skip] another llm-agents update process is running"
  exit 0
fi

cleanup_lock() {
  rmdir "$LOCK_PATH" >/dev/null 2>&1 || true
}
trap cleanup_lock EXIT

if ! command -v git >/dev/null 2>&1; then
  log "[warn] git command not found"
  exit 0
fi
if ! command -v nix >/dev/null 2>&1; then
  log "[warn] nix command not found"
  exit 0
fi

if [ ! -d "$NIX_HOME_DIR/.git" ]; then
  log "[skip] nix-home repository not found: $NIX_HOME_DIR"
  exit 0
fi

cd "$NIX_HOME_DIR"

current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [ "$current_branch" != "$TARGET_BRANCH" ]; then
  log "[skip] current branch is $current_branch (required: $TARGET_BRANCH)"
  exit 0
fi

tracked_dirty_files="$({
  git diff --name-only
  git diff --cached --name-only
} | sort -u)"

non_lock_dirty_files="$(printf '%s\n' "$tracked_dirty_files" | awk 'NF && $0 != "flake.lock"')"
if [ -n "$non_lock_dirty_files" ]; then
  log "[skip] tracked changes exist outside flake.lock"
  exit 0
fi

lock_dirty_before=0
if printf '%s\n' "$tracked_dirty_files" | grep -Fxq "flake.lock"; then
  lock_dirty_before=1
fi

if [ "$lock_dirty_before" -eq 0 ]; then
  if ! git pull --ff-only; then
    log "[warn] git pull --ff-only failed"
    exit 0
  fi
else
  log "[info] flake.lock is already modified; skip git pull"
fi

log "[info] updating llm-agents input in flake.lock"
if ! nix flake lock --update-input llm-agents; then
  log "[warn] nix flake lock --update-input llm-agents failed"
  exit 0
fi

if git diff --quiet -- flake.lock; then
  log "[done] llm-agents is already up to date"
  exit 0
fi

log "[done] flake.lock updated (llm-agents)"

