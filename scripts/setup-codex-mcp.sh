#!/usr/bin/env bash
# Codex MCP servers setup
# MCP: jina, claude-mem
set -euo pipefail

if ! command -v codex >/dev/null 2>&1; then
  echo "[skip] codex: command not found"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[warn] jq: command not found, enabled flag reconciliation may be skipped"
  HAS_JQ=0
else
  HAS_JQ=1
fi

CLAUDE_MEM_MCP_SERVER="${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}/plugins/marketplaces/thedotmack/plugin/scripts/mcp-server.cjs"
JINA_URL="https://mcp.jina.ai/v1?include_tags=search,read&exclude_tools=search_images,search_jina_blog,capture_screenshot_url,search_web"
CODEX_CONFIG_FILE="${CODEX_HOME:-$HOME/.config/codex}/config.toml"
MCP_DEFAULT_ENABLED_RAW="${NIX_HOME_MCP_DEFAULT_ENABLED:-0}"
MCP_FORCE_ENABLED_RAW="${NIX_HOME_MCP_FORCE_ENABLED:-jina,claude-mem}"
MCP_FORCE_DISABLED_RAW="${NIX_HOME_MCP_FORCE_DISABLED:-}"

echo "=== Codex MCP setup ==="

normalize_bool() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) echo "1" ;;
    *) echo "0" ;;
  esac
}

MCP_DEFAULT_ENABLED="$(normalize_bool "$MCP_DEFAULT_ENABLED_RAW")"

contains_csv_token() {
  local csv="$1"
  local token="$2"
  local item

  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    if [ "$item" = "$token" ]; then
      return 0
    fi
  done
  return 1
}

desired_enabled_for_server() {
  local server="$1"

  if contains_csv_token "$MCP_FORCE_DISABLED_RAW" "$server"; then
    if contains_csv_token "$MCP_FORCE_ENABLED_RAW" "$server"; then
      echo "[warn] $server: both force enabled and disabled are set; disabled wins" >&2
    fi
    echo "false"
    return
  fi

  if contains_csv_token "$MCP_FORCE_ENABLED_RAW" "$server"; then
    echo "true"
    return
  fi

  if [ "$MCP_DEFAULT_ENABLED" = "1" ]; then
    echo "true"
  else
    echo "false"
  fi
}

reconcile_server() {
  local name="$1"
  shift

  if codex mcp get "$name" >/dev/null 2>&1; then
    codex mcp remove "$name" >/dev/null
    echo "[info] $name: removed existing configuration"
  fi

  codex mcp add "$name" "$@"
  echo "[done] $name: configured"
}

set_server_enabled_flag() {
  local name="$1"
  local enabled_bool="$2"
  local section="[mcp_servers.${name}]"
  local tmp

  if [ ! -f "$CODEX_CONFIG_FILE" ]; then
    echo "[warn] codex config not found: $CODEX_CONFIG_FILE"
    return 0
  fi

  tmp=$(mktemp)
  awk -v section="$section" -v enabled="$enabled_bool" '
    BEGIN {
      in_section = 0
      seen_section = 0
      wrote_enabled = 0
    }
    function print_enabled() {
      print "enabled = " enabled
      wrote_enabled = 1
    }
    {
      if ($0 ~ /^\[[^]]+\]$/) {
        if (in_section && !wrote_enabled) {
          print_enabled()
        }

        if ($0 == section) {
          in_section = 1
          seen_section = 1
          wrote_enabled = 0
        } else {
          in_section = 0
        }
        print
        next
      }

      if (in_section && $0 ~ /^enabled[[:space:]]*=/) {
        if (!wrote_enabled) {
          print_enabled()
        }
        next
      }

      print
    }
    END {
      if (in_section && !wrote_enabled) {
        print_enabled()
      }
      if (!seen_section) {
        exit 11
      }
    }
  ' "$CODEX_CONFIG_FILE" > "$tmp" || {
    status=$?
    rm -f "$tmp"
    if [ "$status" -eq 11 ]; then
      echo "[warn] codex server section not found in config: $name"
      return 0
    fi
    return "$status"
  }

  mv "$tmp" "$CODEX_CONFIG_FILE"
}

ensure_server_enabled_state() {
  local name="$1"
  local desired_enabled="$2"
  local current_enabled

  if [ "$HAS_JQ" -ne 1 ]; then
    return 0
  fi

  current_enabled=$(codex mcp get "$name" --json 2>/dev/null | jq -r '.enabled // empty')
  if [ -z "$current_enabled" ]; then
    return 0
  fi

  if [ "$current_enabled" = "$desired_enabled" ]; then
    return 0
  fi

  set_server_enabled_flag "$name" "$desired_enabled"
  echo "[done] $name: enabled=$desired_enabled"
}

is_claude_mem_current() {
  local output
  output=$(codex mcp get claude-mem 2>/dev/null || true)
  [ -n "$output" ] &&
    echo "$output" | grep -Fq "transport: stdio" &&
    echo "$output" | grep -Fq "command: node" &&
    echo "$output" | grep -Fq "args: $CLAUDE_MEM_MCP_SERVER"
}

is_jina_current() {
  local output
  output=$(codex mcp get jina 2>/dev/null || true)
  [ -n "$output" ] &&
    echo "$output" | grep -Fq "transport: streamable_http" &&
    echo "$output" | grep -Fq "url: $JINA_URL" &&
    echo "$output" | grep -Fq "bearer_token_env_var: JINA_API_KEY"
}

# claude-mem (stdio)
if [ ! -f "$CLAUDE_MEM_MCP_SERVER" ]; then
  echo "[warn] claude-mem: mcp-server.cjs not found at $CLAUDE_MEM_MCP_SERVER, skipping"
elif is_claude_mem_current; then
  echo "[skip] claude-mem: already up to date"
else
  reconcile_server "claude-mem" -- node "$CLAUDE_MEM_MCP_SERVER"
fi

# jina (streamable HTTP)
if [ -z "${JINA_API_KEY:-}" ]; then
  echo "[warn] jina: JINA_API_KEY is not set, keeping existing configuration"
elif is_jina_current; then
  echo "[skip] jina: already up to date"
else
  reconcile_server "jina" --url "$JINA_URL" --bearer-token-env-var JINA_API_KEY
fi

ensure_server_enabled_state "claude-mem" "$(desired_enabled_for_server "claude-mem")"
ensure_server_enabled_state "jina" "$(desired_enabled_for_server "jina")"

echo "=== Codex MCP setup complete ==="
