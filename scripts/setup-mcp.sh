#!/usr/bin/env bash
# Shared MCP setup entrypoint
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SOPS_ENV_FILE="${SOPS_ENV:-$HOME/.config/sops-nix/secrets/rendered/sops-env.sh}"
CLAUDE_MCP_SCRIPT="${SETUP_CLAUDE_MCP_SCRIPT:-$SCRIPT_DIR/setup-claude-mcp.sh}"
CODEX_MCP_SCRIPT="${SETUP_CODEX_MCP_SCRIPT:-$SCRIPT_DIR/setup-codex-mcp.sh}"
GEMINI_MCP_SCRIPT="${SETUP_GEMINI_MCP_SCRIPT:-$SCRIPT_DIR/setup-gemini-mcp.sh}"
MCP_DEFAULT_ENABLED_RAW="${NIX_HOME_MCP_DEFAULT_ENABLED:-0}"
MCP_FORCE_ENABLED_RAW="${NIX_HOME_MCP_FORCE_ENABLED:-jina,claude-mem}"
MCP_FORCE_DISABLED_RAW="${NIX_HOME_MCP_FORCE_DISABLED:-}"

normalize_bool() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) echo "1" ;;
    *) echo "0" ;;
  esac
}

# Home Manager activation では PATH が不足する場合があるため補完する
if command -v id >/dev/null 2>&1; then
  CURRENT_USER=$(id -un 2>/dev/null || true)
  if [ -n "$CURRENT_USER" ] && [ -d "/etc/profiles/per-user/$CURRENT_USER/bin" ]; then
    PATH="/etc/profiles/per-user/$CURRENT_USER/bin:$PATH"
  fi
fi
if [ -d "/run/current-system/sw/bin" ]; then
  PATH="/run/current-system/sw/bin:$PATH"
fi
if [ -d "$HOME/.nix-profile/bin" ]; then
  PATH="$HOME/.nix-profile/bin:$PATH"
fi
export PATH

# XDG 配置の既定値を明示（launchd や activation で欠落した場合のフォールバック）
: "${CLAUDE_CONFIG_DIR:=$HOME/.config/claude}"
: "${CODEX_HOME:=$HOME/.config/codex}"
: "${GEMINI_CLI_HOME:=$HOME/.config/gemini}"
: "${HAPPY_HOME_DIR:=$HOME/.config/happy}"
NIX_HOME_MCP_DEFAULT_ENABLED="$(normalize_bool "$MCP_DEFAULT_ENABLED_RAW")"
NIX_HOME_MCP_FORCE_ENABLED="${MCP_FORCE_ENABLED_RAW}"
NIX_HOME_MCP_FORCE_DISABLED="${MCP_FORCE_DISABLED_RAW}"
export CLAUDE_CONFIG_DIR CODEX_HOME GEMINI_CLI_HOME HAPPY_HOME_DIR
export NIX_HOME_MCP_DEFAULT_ENABLED NIX_HOME_MCP_FORCE_ENABLED NIX_HOME_MCP_FORCE_DISABLED

if [ -f "$SOPS_ENV_FILE" ]; then
  # shellcheck source=/dev/null
  . "$SOPS_ENV_FILE"
else
  echo "[warn] sops-env.sh not found at $SOPS_ENV_FILE"
fi

sync_launchctl_env() {
  local key="$1"
  local value="${!key:-}"
  local launchctl_bin

  launchctl_bin="$(command -v launchctl 2>/dev/null || true)"
  if [ -z "$launchctl_bin" ] && [ -x "/bin/launchctl" ]; then
    launchctl_bin="/bin/launchctl"
  fi

  if [ -z "$launchctl_bin" ]; then
    return 0
  fi

  if [ -n "$value" ]; then
    if "$launchctl_bin" setenv "$key" "$value"; then
      echo "[done] launchctl env synced: $key"
    else
      echo "[warn] launchctl setenv failed for: $key"
    fi
  else
    "$launchctl_bin" unsetenv "$key" >/dev/null 2>&1 || true
    echo "[warn] $key is not set; launchctl env cleared"
  fi
}

run_setup_script() {
  local script_path="$1"

  if [ ! -f "$script_path" ]; then
    echo "[warn] setup script not found: $script_path"
    return 0
  fi

  if ! bash "$script_path"; then
    echo "[warn] setup script failed: $script_path"
  fi
}

sync_launchctl_env "JINA_API_KEY"

if [ "$NIX_HOME_MCP_DEFAULT_ENABLED" = "1" ]; then
  echo "[info] MCP default mode: enabled"
else
  echo "[info] MCP default mode: disabled"
fi
if [ -n "$NIX_HOME_MCP_FORCE_ENABLED" ]; then
  echo "[info] MCP force enabled: $NIX_HOME_MCP_FORCE_ENABLED"
fi
if [ -n "$NIX_HOME_MCP_FORCE_DISABLED" ]; then
  echo "[info] MCP force disabled: $NIX_HOME_MCP_FORCE_DISABLED"
fi

run_setup_script "$CLAUDE_MCP_SCRIPT"
run_setup_script "$CODEX_MCP_SCRIPT"
run_setup_script "$GEMINI_MCP_SCRIPT"
