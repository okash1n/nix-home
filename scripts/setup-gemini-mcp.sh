#!/usr/bin/env bash
# Gemini CLI MCP servers setup
# MCP: codex, jina, claude-mem
# Gemini CLI has no `gemini mcp add` command, so we edit settings.json directly.
set -euo pipefail

GEMINI_HOME="${GEMINI_CLI_HOME:-$HOME/.config/gemini}"
SETTINGS_FILE="$GEMINI_HOME/settings.json"
CLAUDE_MEM_MCP_SERVER="${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}/plugins/marketplaces/thedotmack/plugin/scripts/mcp-server.cjs"
JINA_URL="https://mcp.jina.ai/v1?include_tags=search,read&exclude_tools=search_images,search_jina_blog,capture_screenshot_url,search_web"

echo "=== Gemini CLI MCP setup ==="

if ! command -v jq >/dev/null 2>&1; then
  echo "[skip] jq: command not found"
  exit 0
fi

if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
  echo "[info] Created $SETTINGS_FILE"
fi

add_mcp_server() {
  local name="$1"
  local config="$2"

  if jq -e ".mcpServers.\"$name\"" "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo "[skip] $name: already configured"
    return 0
  fi

  local tmp
  tmp=$(mktemp)
  jq --argjson server "$config" ".mcpServers.\"$name\" = \$server" "$SETTINGS_FILE" > "$tmp"
  mv "$tmp" "$SETTINGS_FILE"
  echo "[done] $name: added"
}

# Ensure mcpServers key exists
if ! jq -e '.mcpServers' "$SETTINGS_FILE" >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq '. + {mcpServers: {}}' "$SETTINGS_FILE" > "$tmp"
  mv "$tmp" "$SETTINGS_FILE"
fi

# codex (stdio)
if ! command -v codex >/dev/null 2>&1; then
  echo "[warn] codex: command not found, skipping"
else
  add_mcp_server "codex" '{"command": "codex", "args": ["mcp-server"]}'
fi

# jina (httpUrl)
if [ -z "${JINA_API_KEY:-}" ]; then
  echo "[warn] jina: JINA_API_KEY is not set, skipping"
else
  add_mcp_server "jina" "{\"httpUrl\": \"$JINA_URL\", \"headers\": {\"Authorization\": \"Bearer \$JINA_API_KEY\"}}"
fi

# claude-mem (stdio)
if [ ! -f "$CLAUDE_MEM_MCP_SERVER" ]; then
  echo "[warn] claude-mem: mcp-server.cjs not found at $CLAUDE_MEM_MCP_SERVER, skipping"
else
  add_mcp_server "claude-mem" "{\"command\": \"node\", \"args\": [\"$CLAUDE_MEM_MCP_SERVER\"]}"
fi

echo "=== Gemini CLI MCP setup complete ==="
echo "Restart Gemini CLI to apply changes."
