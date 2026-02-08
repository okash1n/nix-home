#!/usr/bin/env bash
# Codex MCP servers setup
# MCP: jina, claude-mem
set -euo pipefail

CLAUDE_MEM_MCP_SERVER="${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}/plugins/marketplaces/thedotmack/plugin/scripts/mcp-server.cjs"
JINA_URL="https://mcp.jina.ai/v1?include_tags=search,read&exclude_tools=search_images,search_jina_blog,capture_screenshot_url"

echo "=== Codex MCP setup ==="

# claude-mem (stdio)
if codex mcp get claude-mem >/dev/null 2>&1; then
  echo "[skip] claude-mem: already configured"
else
  if [ ! -f "$CLAUDE_MEM_MCP_SERVER" ]; then
    echo "[warn] claude-mem: mcp-server.cjs not found at $CLAUDE_MEM_MCP_SERVER, skipping"
  else
    codex mcp add claude-mem -- node "$CLAUDE_MEM_MCP_SERVER"
    echo "[done] claude-mem: added"
  fi
fi

# jina (via mcp-remote, stdio)
if codex mcp get jina >/dev/null 2>&1; then
  echo "[skip] jina: already configured"
else
  if [ -z "${JINA_API_KEY:-}" ]; then
    echo "[warn] jina: JINA_API_KEY is not set, skipping"
  else
    codex mcp add jina -- npx -y mcp-remote "$JINA_URL" \
      --header "Authorization: Bearer ${JINA_API_KEY}"
    echo "[done] jina: added"
  fi
fi

echo "=== Codex MCP setup complete ==="
