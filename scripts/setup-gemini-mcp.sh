#!/usr/bin/env bash
# Gemini CLI MCP servers setup
# MCP: codex, jina, claude-mem, asana, notion
set -euo pipefail

GEMINI_HOME="${GEMINI_CLI_HOME:-$HOME/.config/gemini}"
GEMINI_RUNTIME_HOME="$GEMINI_HOME/.gemini"
SETTINGS_FILE="$GEMINI_RUNTIME_HOME/settings.json"
ENABLEMENT_FILE="$GEMINI_RUNTIME_HOME/mcp-server-enablement.json"
CLAUDE_MEM_MCP_SERVER="${CLAUDE_MEM_MCP_SERVER:-${NIX_HOME_GLOBAL_CLAUDE_CONFIG_DIR:-$HOME/.config/claude}/plugins/marketplaces/thedotmack/plugin/scripts/mcp-server.cjs}"
JINA_URL="https://mcp.jina.ai/v1?include_tags=search,read&exclude_tools=search_images,search_jina_blog,capture_screenshot_url,search_web"
ASANA_URL="https://mcp.asana.com/v2/mcp"
NOTION_URL="https://mcp.notion.com/mcp"
MCP_DEFAULT_ENABLED_RAW="${NIX_HOME_MCP_DEFAULT_ENABLED:-0}"
MCP_FORCE_ENABLED_RAW="${NIX_HOME_MCP_FORCE_ENABLED:-jina,claude-mem}"
MCP_FORCE_DISABLED_RAW="${NIX_HOME_MCP_FORCE_DISABLED:-}"

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

echo "=== Gemini CLI MCP setup ==="

if ! command -v jq >/dev/null 2>&1; then
  echo "[skip] jq: command not found"
  exit 0
fi

mkdir -p "$GEMINI_RUNTIME_HOME"

ensure_json_object_file() {
  local file_path="$1"
  local label="$2"

  if [ ! -f "$file_path" ]; then
    echo '{}' > "$file_path"
    echo "[info] Created $file_path"
  fi

  if ! jq -e 'type == "object"' "$file_path" >/dev/null 2>&1; then
    echo "[warn] gemini: $label is not a JSON object ($file_path), skipping"
    exit 0
  fi
}

ensure_json_object_file "$SETTINGS_FILE" "settings.json"
ensure_json_object_file "$ENABLEMENT_FILE" "mcp-server-enablement.json"

if jq -e '.mcpServers and (.mcpServers | type != "object")' "$SETTINGS_FILE" >/dev/null 2>&1; then
  echo "[warn] gemini: .mcpServers is not an object in $SETTINGS_FILE, skipping"
  exit 0
fi

# Ensure mcpServers key exists
if ! jq -e '.mcpServers' "$SETTINGS_FILE" >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq '. + {mcpServers: {}}' "$SETTINGS_FILE" > "$tmp"
  mv "$tmp" "$SETTINGS_FILE"
fi

upsert_mcp_server() {
  local name="$1"
  local config="$2"
  local desired current tmp

  desired=$(printf '%s' "$config" | jq -c '.')
  current=$(jq -c ".mcpServers.\"$name\" // empty" "$SETTINGS_FILE")

  if [ "$current" = "$desired" ]; then
    echo "[skip] $name: already up to date"
    return
  fi

  tmp=$(mktemp)
  jq --argjson server "$config" ".mcpServers.\"$name\" = \$server" "$SETTINGS_FILE" > "$tmp"
  mv "$tmp" "$SETTINGS_FILE"
  echo "[done] $name: configured"
}

set_server_enabled_state() {
  local name="$1"
  local should_enable="$2"
  local current_state desired_state tmp

  current_state=$(jq -c ".\"$name\" // empty" "$ENABLEMENT_FILE")
  if [ "$should_enable" = "true" ]; then
    if [ -z "$current_state" ]; then
      return
    fi
    tmp=$(mktemp)
    jq "del(.\"$name\")" "$ENABLEMENT_FILE" > "$tmp"
    mv "$tmp" "$ENABLEMENT_FILE"
    echo "[done] $name: enabled=true"
    return
  fi

  desired_state='{"enabled":false}'
  if [ "$current_state" = "$desired_state" ]; then
    return
  fi

  tmp=$(mktemp)
  jq ".\"$name\" = {enabled: false}" "$ENABLEMENT_FILE" > "$tmp"
  mv "$tmp" "$ENABLEMENT_FILE"
  echo "[done] $name: enabled=false"
}

# codex (stdio)
if ! command -v codex >/dev/null 2>&1; then
  echo "[warn] codex: command not found, skipping"
else
  CODEX_CONFIG=$(jq -nc '{command: "codex", args: ["mcp-server"]}')
  upsert_mcp_server "codex" "$CODEX_CONFIG"
fi

# jina (http)
if [ -z "${JINA_API_KEY:-}" ]; then
  echo "[warn] jina: JINA_API_KEY is not set, keeping existing configuration"
else
  JINA_CONFIG=$(jq -nc --arg url "$JINA_URL" --arg auth 'Bearer ${JINA_API_KEY}' '{url: $url, type: "http", headers: {Authorization: $auth}}')
  upsert_mcp_server "jina" "$JINA_CONFIG"
fi

# claude-mem (stdio)
if [ ! -f "$CLAUDE_MEM_MCP_SERVER" ]; then
  echo "[warn] claude-mem: mcp-server.cjs not found at $CLAUDE_MEM_MCP_SERVER, skipping"
else
  CLAUDE_MEM_CONFIG=$(jq -nc --arg path "$CLAUDE_MEM_MCP_SERVER" '{command: "node", args: [$path]}')
  upsert_mcp_server "claude-mem" "$CLAUDE_MEM_CONFIG"
fi

# asana (http / OAuth)
ASANA_CONFIG=$(jq -nc --arg url "$ASANA_URL" '{url: $url, type: "http"}')
upsert_mcp_server "asana" "$ASANA_CONFIG"

# notion (http / OAuth)
NOTION_CONFIG=$(jq -nc --arg url "$NOTION_URL" '{url: $url, type: "http"}')
upsert_mcp_server "notion" "$NOTION_CONFIG"

for server_name in codex jina claude-mem asana notion; do
  if ! jq -e ".mcpServers.\"$server_name\"" "$SETTINGS_FILE" >/dev/null 2>&1; then
    continue
  fi

  set_server_enabled_state "$server_name" "$(desired_enabled_for_server "$server_name")"
done

echo "=== Gemini CLI MCP setup complete ==="
echo "Restart Gemini CLI to apply changes."
