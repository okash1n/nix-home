#!/usr/bin/env bash
# Claude Code MCP servers setup
# MCP: codex, jina
set -euo pipefail

echo "=== Claude Code MCP setup ==="

# codex (stdio)
if claude mcp get codex >/dev/null 2>&1; then
  echo "[skip] codex: already configured"
else
  claude mcp add codex --scope user -- codex mcp-server
  echo "[done] codex: added"
fi

# jina (http, filtered)
JINA_URL="https://mcp.jina.ai/v1?include_tags=search,read&exclude_tools=search_images,search_jina_blog,capture_screenshot_url"
if claude mcp get jina >/dev/null 2>&1; then
  echo "[skip] jina: already configured"
else
  if [ -z "${JINA_API_KEY:-}" ]; then
    echo "[warn] jina: JINA_API_KEY is not set, skipping"
  else
    # 注意: Claude の HTTP MCP は ${VAR} の遅延展開をサポートしないため、
    # 実際の API キー値が settings.json に平文保存される。
    # API キーは sops-nix で管理され、sops-env.sh 経由で環境変数に設定される。
    claude mcp add -s user --transport http jina "$JINA_URL" \
      --header "Authorization: Bearer ${JINA_API_KEY}"
    echo "[done] jina: added"
  fi
fi

echo "=== Claude Code MCP setup complete ==="
echo "Restart Claude Code to apply changes."
