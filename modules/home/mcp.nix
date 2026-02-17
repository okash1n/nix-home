{ lib, pkgs, ... }:
{
  # sops 適用後に MCP 設定と launchctl 環境変数を同期
  home.activation.setupMcpServers = lib.hm.dag.entryAfter [ "sops-nix" ] ''
    SETUP_CLAUDE_MCP_SCRIPT=${../../scripts/setup-claude-mcp.sh} \
    SETUP_CODEX_MCP_SCRIPT=${../../scripts/setup-codex-mcp.sh} \
    SETUP_GEMINI_MCP_SCRIPT=${../../scripts/setup-gemini-mcp.sh} \
    ${pkgs.bash}/bin/bash ${../../scripts/setup-mcp.sh}
  '';
}
