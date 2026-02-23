#!/usr/bin/env bash
# llm-agents input auto updater
set -euo pipefail

NIX_HOME_DIR="${NIX_HOME_DIR:-$HOME/nix-home}"
TARGET_BRANCH="${NIX_HOME_LLM_AGENTS_UPDATE_BRANCH:-main}"
TARGET_REMOTE="${NIX_HOME_LLM_AGENTS_UPDATE_REMOTE:-origin}"
STATE_DIR="${NIX_HOME_STATE_DIR:-$HOME/.local/state/nix-home}"
LOCK_DIR="$STATE_DIR/locks"
LOCK_PATH="$LOCK_DIR/llm-agents-auto-update.lock"
WORKTREES_DIR="$STATE_DIR/worktrees"
UPDATE_WORKTREE_DIR="${NIX_HOME_LLM_AGENTS_UPDATE_WORKTREE_DIR:-$WORKTREES_DIR/llm-agents-auto-update}"
AUTO_APPLY_SWITCH="${NIX_HOME_LLM_AGENTS_AUTO_SWITCH:-1}"
NIX_HOME_USERNAME="${NIX_HOME_USERNAME:-$(id -un 2>/dev/null || echo "$USER")}"
LOCK_WAIT_SECONDS="${NIX_HOME_LLM_AGENTS_LOCK_WAIT_SECONDS:-0}"
LOCK_WAIT_INTERVAL_SECONDS=5
RETRY_COUNT="${NIX_HOME_LLM_AGENTS_RETRY_COUNT:-3}"
RETRY_INTERVAL_SECONDS="${NIX_HOME_LLM_AGENTS_RETRY_INTERVAL_SECONDS:-20}"

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

resolve_flake_target() {
  local repo_root="$1"
  local host_short host_cfg
  host_short="$(hostname -s 2>/dev/null || hostname)"
  host_cfg="$repo_root/hosts/darwin/$host_short.nix"

  if [ -f "$host_cfg" ]; then
    printf '%s\n' "$host_short"
  else
    printf '%s\n' "default"
  fi
}

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*"
}

acquire_lock() {
  local waited=0

  while ! mkdir "$LOCK_PATH" >/dev/null 2>&1; do
    if [ "$LOCK_WAIT_SECONDS" -gt 0 ] && [ "$waited" -ge "$LOCK_WAIT_SECONDS" ]; then
      log "[error] lock wait timeout (${LOCK_WAIT_SECONDS}s): another llm-agents update process may be stuck"
      return 1
    fi

    sleep "$LOCK_WAIT_INTERVAL_SECONDS"
    waited=$((waited + LOCK_WAIT_INTERVAL_SECONDS))
  done

  return 0
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

resolve_home_activation_package() {
  local attr_path="$1"
  local attempt=1
  local out=""

  while true; do
    if out="$(nix build --impure --no-link --print-out-paths "$UPDATE_WORKTREE_DIR#$attr_path")"; then
      printf '%s\n' "$out"
      return 0
    fi

    if [ "$attempt" -ge "$RETRY_COUNT" ]; then
      log "[error] home activation package build failed after ${attempt} attempts"
      return 1
    fi

    log "[warn] home activation package build failed (attempt ${attempt}/${RETRY_COUNT}); retrying in ${RETRY_INTERVAL_SECONDS}s"
    sleep "$RETRY_INTERVAL_SECONDS"
    attempt=$((attempt + 1))
  done
}

read_ai_cli_version() {
  local cli="$1"
  local resolved version_line

  if ! resolved="$(command -v "$cli" 2>/dev/null)"; then
    printf '%s\n' "<not found>"
    return 0
  fi

  version_line="$("$cli" --version 2>/dev/null | head -n 1 || true)"
  if [ -n "$version_line" ]; then
    printf '%s\n' "$version_line"
  else
    printf '%s\n' "path:$resolved"
  fi
}

verify_ai_cli_commands() {
  local before_codex="$1"
  local before_claude="$2"
  local before_gemini="$3"
  local cli resolved before_version after_version

  for cli in codex claude gemini; do
    if ! resolved="$(command -v "$cli" 2>/dev/null)"; then
      log "[error] command not found after switch: $cli"
      return 1
    fi

    after_version="$(read_ai_cli_version "$cli")"
    case "$cli" in
      codex)
        before_version="$before_codex"
        ;;
      claude)
        before_version="$before_claude"
        ;;
      gemini)
        before_version="$before_gemini"
        ;;
    esac

    log "[done] $cli: $after_version"
    log "[done] $cli transition: $before_version -> $after_version"
  done

  return 0
}

prepare_update_worktree() {
  local target_ref="$TARGET_REMOTE/$TARGET_BRANCH"

  git -C "$NIX_HOME_DIR" worktree prune >/dev/null 2>&1 || true

  if [ -e "$UPDATE_WORKTREE_DIR" ] && ! git -C "$UPDATE_WORKTREE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "[warn] invalid update worktree detected, recreating: $UPDATE_WORKTREE_DIR"
    rm -rf "$UPDATE_WORKTREE_DIR"
  fi

  if [ ! -e "$UPDATE_WORKTREE_DIR" ]; then
    if ! git -C "$NIX_HOME_DIR" worktree add --force --detach "$UPDATE_WORKTREE_DIR" "$target_ref"; then
      log "[error] failed to create update worktree: $UPDATE_WORKTREE_DIR"
      return 1
    fi
  fi

  if ! git -C "$UPDATE_WORKTREE_DIR" checkout --detach "$target_ref" >/dev/null 2>&1; then
    log "[warn] failed to checkout $target_ref in existing worktree, recreating"
    rm -rf "$UPDATE_WORKTREE_DIR"
    git -C "$NIX_HOME_DIR" worktree prune >/dev/null 2>&1 || true

    if ! git -C "$NIX_HOME_DIR" worktree add --force --detach "$UPDATE_WORKTREE_DIR" "$target_ref"; then
      log "[error] failed to recreate update worktree: $UPDATE_WORKTREE_DIR"
      return 1
    fi
  fi

  if ! git -C "$UPDATE_WORKTREE_DIR" reset --hard "$target_ref" >/dev/null 2>&1; then
    log "[error] failed to reset update worktree to $target_ref"
    return 1
  fi

  if ! git -C "$UPDATE_WORKTREE_DIR" clean -fd >/dev/null 2>&1; then
    log "[error] failed to clean update worktree: $UPDATE_WORKTREE_DIR"
    return 1
  fi

  return 0
}

mkdir -p "$STATE_DIR" "$LOCK_DIR" "$WORKTREES_DIR"

if ! acquire_lock; then
  exit 1
fi

cleanup_lock() {
  rmdir "$LOCK_PATH" >/dev/null 2>&1 || true
}
trap cleanup_lock EXIT

if ! command -v git >/dev/null 2>&1; then
  log "[error] git command not found"
  exit 1
fi
if ! command -v nix >/dev/null 2>&1; then
  log "[error] nix command not found"
  exit 1
fi

if [ ! -d "$NIX_HOME_DIR/.git" ]; then
  log "[error] nix-home repository not found: $NIX_HOME_DIR"
  exit 1
fi

if ! git -C "$NIX_HOME_DIR" remote get-url "$TARGET_REMOTE" >/dev/null 2>&1; then
  log "[error] git remote not found: $TARGET_REMOTE"
  exit 1
fi

log "[info] fetching latest branch: $TARGET_REMOTE/$TARGET_BRANCH"
if ! run_with_retry "git fetch $TARGET_REMOTE/$TARGET_BRANCH" git -C "$NIX_HOME_DIR" fetch --prune "$TARGET_REMOTE" "$TARGET_BRANCH"; then
  log "[error] failed to fetch $TARGET_REMOTE/$TARGET_BRANCH"
  exit 1
fi

if ! prepare_update_worktree; then
  exit 1
fi

cd "$UPDATE_WORKTREE_DIR"

log "[info] updating llm-agents input in flake.lock (worktree: $UPDATE_WORKTREE_DIR)"
if ! run_with_retry "nix flake lock --update-input llm-agents" nix flake lock --update-input llm-agents; then
  log "[error] nix flake lock --update-input llm-agents failed"
  exit 1
fi

if git diff --quiet -- flake.lock; then
  log "[info] llm-agents is already up to date"
else
  log "[done] flake.lock updated (llm-agents)"
fi

if [ "$AUTO_APPLY_SWITCH" != "1" ]; then
  log "[info] auto-apply is disabled (NIX_HOME_LLM_AGENTS_AUTO_SWITCH=$AUTO_APPLY_SWITCH)"
  exit 0
fi

target_name="$(resolve_flake_target "$UPDATE_WORKTREE_DIR")"
home_attr_path="darwinConfigurations.${target_name}.config.home-manager.users.${NIX_HOME_USERNAME}.home.activationPackage"
before_codex="$(read_ai_cli_version codex)"
before_claude="$(read_ai_cli_version claude)"
before_gemini="$(read_ai_cli_version gemini)"

log "[info] building home activation package: $home_attr_path"
if ! home_activation_path="$(resolve_home_activation_package "$home_attr_path")"; then
  exit 1
fi

if [ -d "$home_activation_path" ] && [ -x "$home_activation_path/activate" ]; then
  home_activation_cmd="$home_activation_path/activate"
elif [ -x "$home_activation_path" ]; then
  home_activation_cmd="$home_activation_path"
else
  log "[error] built activation package is not executable: $home_activation_path"
  exit 1
fi

log "[info] applying home activation: $home_activation_cmd"
if ! run_with_retry "home-manager activation" "$home_activation_cmd"; then
  log "[error] home activation failed"
  exit 1
fi

if ! verify_ai_cli_commands "$before_codex" "$before_claude" "$before_gemini"; then
  exit 1
fi

log "[done] home-manager switch applied"
