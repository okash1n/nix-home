#!/usr/bin/env bash
# Nightly updater: run `make update` safely from launchd.
set -euo pipefail

NIX_HOME_DIR="${NIX_HOME_DIR:-$HOME/nix-home}"
STATE_DIR="${NIX_HOME_STATE_DIR:-$HOME/.local/state/nix-home}"
LOCK_DIR="$STATE_DIR/locks"
LOCK_PATH="$LOCK_DIR/make-update-nightly.lock"
NIX_HOME_USERNAME="${NIX_HOME_USERNAME:-$(id -un 2>/dev/null || echo "$USER")}"
RETRY_COUNT="${NIX_HOME_UPDATE_RETRY_COUNT:-2}"
RETRY_INTERVAL_SECONDS="${NIX_HOME_UPDATE_RETRY_INTERVAL_SECONDS:-30}"

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
if [ -x "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*"
}

run_with_retry() {
  local description="$1"
  shift
  local attempt=1

  while true; do
    if "$@"; then
      return 0
    fi

    if [ "$attempt" -ge "$RETRY_COUNT" ]; then
      log "[error] $description failed after ${attempt} attempts"
      return 1
    fi

    log "[warn] $description failed (attempt ${attempt}/${RETRY_COUNT}); retrying in ${RETRY_INTERVAL_SECONDS}s"
    sleep "$RETRY_INTERVAL_SECONDS"
    attempt=$((attempt + 1))
  done
}

mkdir -p "$STATE_DIR" "$LOCK_DIR"

if ! mkdir "$LOCK_PATH" >/dev/null 2>&1; then
  log "[skip] another nightly update is already running"
  exit 0
fi

cleanup_lock() {
  rmdir "$LOCK_PATH" >/dev/null 2>&1 || true
}
trap cleanup_lock EXIT

if ! command -v make >/dev/null 2>&1; then
  log "[error] make command not found"
  exit 1
fi

if [ ! -d "$NIX_HOME_DIR/.git" ]; then
  log "[error] nix-home repository not found: $NIX_HOME_DIR"
  exit 1
fi

cd "$NIX_HOME_DIR"

log "[info] starting nightly make update"
if ! run_with_retry "make update" make update NIX_HOME_USERNAME="$NIX_HOME_USERNAME"; then
  log "[error] nightly make update failed"
  exit 1
fi

log "[done] nightly make update completed"

