#!/usr/bin/env bash
# Codex MCP servers setup
# MCP: jina, claude-mem, asana, notion
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

CLAUDE_MEM_MCP_SERVER="${CLAUDE_MEM_MCP_SERVER:-${NIX_HOME_GLOBAL_CLAUDE_CONFIG_DIR:-$HOME/.config/claude}/plugins/marketplaces/thedotmack/plugin/scripts/mcp-server.cjs}"
JINA_URL="https://mcp.jina.ai/v1?include_tags=search,read&exclude_tools=search_images,search_jina_blog,capture_screenshot_url,search_web"
ASANA_URL="https://mcp.asana.com/v2/mcp"
NOTION_URL="https://mcp.notion.com/mcp"
MCP_REMOTE_COMMAND="${MCP_REMOTE_COMMAND:-npx}"
MCP_REMOTE_STARTUP_TIMEOUT_SEC="${MCP_REMOTE_STARTUP_TIMEOUT_SEC:-60}"
ASANA_MCP_CALLBACK_HOST="${ASANA_MCP_CALLBACK_HOST:-127.0.0.1}"
ASANA_MCP_CALLBACK_PORT="${ASANA_MCP_CALLBACK_PORT:-9554}"
ASANA_MCP_CLIENT_ID="${ASANA_MCP_CLIENT_ID:-}"
ASANA_MCP_CLIENT_SECRET="${ASANA_MCP_CLIENT_SECRET:-}"
ASANA_MCP_CLIENT_INFO_FILE="${ASANA_MCP_CLIENT_INFO_FILE:-$HOME/.mcp-auth/mcp-remote-0.1.37/asana_client_info.json}"
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
ASANA_STATIC_CLIENT_READY=0
ASANA_CLIENT_INFO_ARG=""

prepare_asana_static_client_info() {
  local tmp

  ASANA_STATIC_CLIENT_READY=0
  ASANA_CLIENT_INFO_ARG=""

  if [ -z "$ASANA_MCP_CLIENT_ID" ] || [ -z "$ASANA_MCP_CLIENT_SECRET" ]; then
    return 1
  fi

  if [ "$HAS_JQ" -ne 1 ]; then
    echo "[warn] asana: jq not found; static OAuth client info generation is unavailable"
    return 1
  fi

  mkdir -p "$(dirname "$ASANA_MCP_CLIENT_INFO_FILE")"
  tmp=$(mktemp)
  jq -cn --arg id "$ASANA_MCP_CLIENT_ID" --arg secret "$ASANA_MCP_CLIENT_SECRET" \
    '{client_id: $id, client_secret: $secret}' > "$tmp" || {
      rm -f "$tmp"
      return 1
    }
  chmod 600 "$tmp" || {
    rm -f "$tmp"
    return 1
  }
  mv "$tmp" "$ASANA_MCP_CLIENT_INFO_FILE" || {
    rm -f "$tmp"
    return 1
  }
  chmod 600 "$ASANA_MCP_CLIENT_INFO_FILE" || return 1

  ASANA_STATIC_CLIENT_READY=1
  ASANA_CLIENT_INFO_ARG="@$ASANA_MCP_CLIENT_INFO_FILE"
  return 0
}

if ! prepare_asana_static_client_info; then
  ASANA_STATIC_CLIENT_READY=0
  ASANA_CLIENT_INFO_ARG=""
fi

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

  if [ "$server" = "asana" ] && [ "$ASANA_STATIC_CLIENT_READY" -ne 1 ]; then
    if contains_csv_token "$MCP_FORCE_DISABLED_RAW" "$server"; then
      echo "false"
      return
    fi

    if contains_csv_token "$MCP_FORCE_ENABLED_RAW" "$server" || [ "$MCP_DEFAULT_ENABLED" = "1" ]; then
      echo "[warn] asana: forcing disabled because ASANA_MCP_CLIENT_ID / ASANA_MCP_CLIENT_SECRET are not set" >&2
      echo "[warn] asana: Asana MCP v2 requires pre-registered OAuth client info (no dynamic client registration)" >&2
    fi
    echo "false"
    return
  fi

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

set_server_section_value() {
  local name="$1"
  local key="$2"
  local value="$3"
  local section="[mcp_servers.${name}]"
  local tmp

  if [ ! -f "$CODEX_CONFIG_FILE" ]; then
    echo "[warn] codex config not found: $CODEX_CONFIG_FILE"
    return 0
  fi

  tmp=$(mktemp)
  awk -v section="$section" -v key="$key" -v value="$value" '
    BEGIN {
      in_section = 0
      seen_section = 0
      wrote_key = 0
      key_pattern = "^" key "[[:space:]]*="
    }
    function print_key_value() {
      print key " = " value
      wrote_key = 1
    }
    {
      if ($0 ~ /^\[[^]]+\]$/) {
        if (in_section && !wrote_key) {
          print_key_value()
        }

        if ($0 == section) {
          in_section = 1
          seen_section = 1
          wrote_key = 0
        } else {
          in_section = 0
        }
        print
        next
      }

      if (in_section && $0 ~ key_pattern) {
        if (!wrote_key) {
          print_key_value()
        }
        next
      }

      print
    }
    END {
      if (in_section && !wrote_key) {
        print_key_value()
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

set_server_enabled_flag() {
  local name="$1"
  local enabled_bool="$2"
  set_server_section_value "$name" "enabled" "$enabled_bool"
}

set_server_startup_timeout() {
  local name="$1"
  local timeout_sec="$2"
  set_server_section_value "$name" "startup_timeout_sec" "$timeout_sec"
}

ensure_server_enabled_state() {
  local name="$1"
  local desired_enabled="$2"
  local current_enabled

  if [ "$HAS_JQ" -ne 1 ]; then
    return 0
  fi

  current_enabled=$(codex mcp get "$name" --json 2>/dev/null | jq -r '.enabled // empty')
  if [ -n "$current_enabled" ] && [ "$current_enabled" = "$desired_enabled" ]; then
    return 0
  fi

  set_server_enabled_flag "$name" "$desired_enabled"
  echo "[done] $name: enabled=$desired_enabled"
}

ensure_server_startup_timeout() {
  local name="$1"
  local desired_timeout="$2"
  local current_timeout

  if [ "$HAS_JQ" -ne 1 ]; then
    return 0
  fi

  current_timeout=$(codex mcp get "$name" --json 2>/dev/null | jq -r '.startup_timeout_sec // empty')
  if [ "$current_timeout" = "$desired_timeout" ] || [ "$current_timeout" = "${desired_timeout}.0" ]; then
    return 0
  fi

  set_server_startup_timeout "$name" "$desired_timeout"
  echo "[done] $name: startup_timeout_sec=$desired_timeout"
}

is_claude_mem_current() {
  local output
  if [ "$HAS_JQ" -eq 1 ]; then
    output=$(codex mcp get claude-mem --json 2>/dev/null || true)
    [ -n "$output" ] &&
      jq -e --arg path "$CLAUDE_MEM_MCP_SERVER" '
        .transport.type == "stdio" and
        .transport.command == "node" and
        (.transport.args // []) == [$path]
      ' >/dev/null <<<"$output"
    return $?
  fi

  output=$(codex mcp get claude-mem 2>/dev/null || true)
  [ -n "$output" ] &&
    echo "$output" | grep -Fq "transport: stdio" &&
    echo "$output" | grep -Fq "command: node" &&
    echo "$output" | grep -Fq "args: $CLAUDE_MEM_MCP_SERVER"
}

is_jina_current() {
  local output
  if [ "$HAS_JQ" -eq 1 ]; then
    output=$(codex mcp get jina --json 2>/dev/null || true)
    [ -n "$output" ] &&
      jq -e --arg url "$JINA_URL" '
        .transport.type == "streamable_http" and
        .transport.url == $url and
        .transport.bearer_token_env_var == "JINA_API_KEY"
      ' >/dev/null <<<"$output"
    return $?
  fi

  output=$(codex mcp get jina 2>/dev/null || true)
  [ -n "$output" ] &&
    echo "$output" | grep -Fq "transport: streamable_http" &&
    echo "$output" | grep -Fq "url: $JINA_URL" &&
    echo "$output" | grep -Fq "bearer_token_env_var: JINA_API_KEY"
}

is_asana_current() {
  local output
  if [ "$HAS_JQ" -eq 1 ]; then
    output=$(codex mcp get asana --json 2>/dev/null || true)
    [ -n "$output" ] || return 1

    if [ "$ASANA_STATIC_CLIENT_READY" -eq 1 ]; then
      jq -e \
        --arg command "$MCP_REMOTE_COMMAND" \
        --arg url "$ASANA_URL" \
        --arg port "$ASANA_MCP_CALLBACK_PORT" \
        --arg host "$ASANA_MCP_CALLBACK_HOST" \
        --arg client_info_arg "$ASANA_CLIENT_INFO_ARG" '
          .transport.type == "stdio" and
          .transport.command == $command and
          (.transport.args // []) == ["-y", "mcp-remote", $url, $port, "--host", $host, "--static-oauth-client-info", $client_info_arg]
        ' >/dev/null <<<"$output"
    else
      jq -e --arg command "$MCP_REMOTE_COMMAND" --arg url "$ASANA_URL" '
        .transport.type == "stdio" and
        .transport.command == $command and
        (.transport.args // []) == ["-y", "mcp-remote", $url]
      ' >/dev/null <<<"$output"
    fi
    return $?
  fi

  output=$(codex mcp get asana 2>/dev/null || true)
  [ -n "$output" ] || return 1

  if [ "$ASANA_STATIC_CLIENT_READY" -eq 1 ]; then
    echo "$output" | grep -Fq "transport: stdio" &&
      echo "$output" | grep -Fq "command: $MCP_REMOTE_COMMAND" &&
      echo "$output" | grep -Fq "args: -y mcp-remote $ASANA_URL $ASANA_MCP_CALLBACK_PORT --host $ASANA_MCP_CALLBACK_HOST --static-oauth-client-info $ASANA_CLIENT_INFO_ARG"
  else
    echo "$output" | grep -Fq "transport: stdio" &&
      echo "$output" | grep -Fq "command: $MCP_REMOTE_COMMAND" &&
      echo "$output" | grep -Fq "args: -y mcp-remote $ASANA_URL"
  fi
}

is_notion_current() {
  local output
  if [ "$HAS_JQ" -eq 1 ]; then
    output=$(codex mcp get notion --json 2>/dev/null || true)
    [ -n "$output" ] &&
      jq -e --arg command "$MCP_REMOTE_COMMAND" --arg url "$NOTION_URL" '
        .transport.type == "stdio" and
        .transport.command == $command and
        (.transport.args // []) == ["-y", "mcp-remote", $url]
      ' >/dev/null <<<"$output"
    return $?
  fi

  output=$(codex mcp get notion 2>/dev/null || true)
  [ -n "$output" ] &&
    echo "$output" | grep -Fq "transport: stdio" &&
    echo "$output" | grep -Fq "command: $MCP_REMOTE_COMMAND" &&
    echo "$output" | grep -Fq "args: -y mcp-remote $NOTION_URL"
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

# Asana/Notion は OAuth が必須。
# Notion は mcp-remote のデフォルト OAuth で接続できるが、
# Asana v2 は動的クライアント登録を受け付けないため、
# 事前登録済み client info（ASANA_MCP_CLIENT_ID / ASANA_MCP_CLIENT_SECRET）が必要。
if ! command -v "$MCP_REMOTE_COMMAND" >/dev/null 2>&1; then
  echo "[warn] asana/notion: $MCP_REMOTE_COMMAND not found, skipping"
else
  # asana (stdio via mcp-remote)
  if [ "$ASANA_STATIC_CLIENT_READY" -ne 1 ]; then
    echo "[warn] asana: static OAuth client info is not configured; skip reconcile"
  elif is_asana_current; then
    echo "[skip] asana: already up to date"
  else
    reconcile_server \
      "asana" -- \
      "$MCP_REMOTE_COMMAND" -y mcp-remote "$ASANA_URL" "$ASANA_MCP_CALLBACK_PORT" \
      --host "$ASANA_MCP_CALLBACK_HOST" \
      --static-oauth-client-info "$ASANA_CLIENT_INFO_ARG"
  fi

  # notion (stdio via mcp-remote)
  if is_notion_current; then
    echo "[skip] notion: already up to date"
  else
    reconcile_server "notion" -- "$MCP_REMOTE_COMMAND" -y mcp-remote "$NOTION_URL"
  fi
fi

ensure_server_enabled_state "claude-mem" "$(desired_enabled_for_server "claude-mem")"
ensure_server_enabled_state "jina" "$(desired_enabled_for_server "jina")"
ensure_server_enabled_state "asana" "$(desired_enabled_for_server "asana")"
ensure_server_enabled_state "notion" "$(desired_enabled_for_server "notion")"
ensure_server_startup_timeout "asana" "$MCP_REMOTE_STARTUP_TIMEOUT_SEC"
ensure_server_startup_timeout "notion" "$MCP_REMOTE_STARTUP_TIMEOUT_SEC"

echo "=== Codex MCP setup complete ==="
