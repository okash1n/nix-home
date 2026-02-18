#!/usr/bin/env bash
# Claude Code MCP servers setup
# MCP: codex, jina, asana, notion
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "[skip] claude: command not found"
  exit 0
fi

echo "=== Claude Code MCP setup ==="
MCP_DEFAULT_ENABLED_RAW="${NIX_HOME_MCP_DEFAULT_ENABLED:-0}"
MCP_FORCE_ENABLED_RAW="${NIX_HOME_MCP_FORCE_ENABLED:-jina,claude-mem}"
MCP_FORCE_DISABLED_RAW="${NIX_HOME_MCP_FORCE_DISABLED:-}"
JINA_URL="https://mcp.jina.ai/v1?include_tags=search,read&exclude_tools=search_images,search_jina_blog,capture_screenshot_url,search_web"
ASANA_URL="https://mcp.asana.com/v2/mcp"
NOTION_URL="https://mcp.notion.com/mcp"

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

remove_user_server() {
  local name="$1"
  if claude mcp remove "$name" --scope user >/dev/null 2>&1; then
    echo "[info] $name: removed existing user configuration"
  fi
}

is_codex_current() {
  local output
  output=$(claude mcp get codex 2>/dev/null || true)
  [ -n "$output" ] &&
    echo "$output" | grep -Fq "Scope: User config" &&
    echo "$output" | grep -Fq "Type: stdio" &&
    echo "$output" | grep -Fq "Command: codex" &&
    echo "$output" | grep -Fq "Args: mcp-server"
}

is_jina_current() {
  local output
  output=$(claude mcp get jina 2>/dev/null || true)
  [ -n "$output" ] &&
    echo "$output" | grep -Fq "Scope: User config" &&
    echo "$output" | grep -Fq "Type: http" &&
    echo "$output" | grep -Fq "URL: $JINA_URL" &&
    echo "$output" | grep -Fq "Authorization: Bearer ${JINA_API_KEY}"
}

is_asana_current() {
  local output
  output=$(claude mcp get asana 2>/dev/null || true)
  [ -n "$output" ] &&
    echo "$output" | grep -Fq "Scope: User config" &&
    echo "$output" | grep -Fq "Type: http" &&
    echo "$output" | grep -Fq "URL: $ASANA_URL"
}

is_notion_current() {
  local output
  output=$(claude mcp get notion 2>/dev/null || true)
  [ -n "$output" ] &&
    echo "$output" | grep -Fq "Scope: User config" &&
    echo "$output" | grep -Fq "Type: http" &&
    echo "$output" | grep -Fq "URL: $NOTION_URL"
}

if [ "$(desired_enabled_for_server "codex")" = "true" ]; then
  # codex (stdio)
  if is_codex_current; then
    echo "[skip] codex: already up to date"
  else
    remove_user_server "codex"
    claude mcp add --scope user codex -- codex mcp-server
    echo "[done] codex: configured"
  fi
else
  remove_user_server "codex"
fi

if [ "$(desired_enabled_for_server "jina")" = "true" ]; then
  # jina (http, filtered)
  if [ -z "${JINA_API_KEY:-}" ]; then
    echo "[warn] jina: JINA_API_KEY is not set, keeping existing user configuration"
  elif is_jina_current; then
    echo "[skip] jina: already up to date"
  else
    # 注意: Claude の HTTP MCP は ${VAR} の遅延展開をサポートしないため、
    # 実際の API キー値が settings.json に平文保存される。
    # API キーは sops-nix で管理され、sops-env.sh 経由で環境変数に設定される。
    remove_user_server "jina"
    claude mcp add --scope user --transport http jina "$JINA_URL" \
      --header "Authorization: Bearer ${JINA_API_KEY}"
    echo "[done] jina: configured"
  fi
else
  remove_user_server "jina"
fi

if [ "$(desired_enabled_for_server "asana")" = "true" ]; then
  if is_asana_current; then
    echo "[skip] asana: already up to date"
  else
    remove_user_server "asana"
    claude mcp add --scope user --transport http asana "$ASANA_URL"
    echo "[done] asana: configured"
  fi
else
  remove_user_server "asana"
fi

if [ "$(desired_enabled_for_server "notion")" = "true" ]; then
  if is_notion_current; then
    echo "[skip] notion: already up to date"
  else
    remove_user_server "notion"
    claude mcp add --scope user --transport http notion "$NOTION_URL"
    echo "[done] notion: configured"
  fi
else
  remove_user_server "notion"
fi

echo "=== Claude Code MCP setup complete ==="
echo "Restart Claude Code to apply changes."
