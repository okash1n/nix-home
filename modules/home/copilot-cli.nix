{ lib, ... }:
{
  # Copilot CLI の静的設定は Home Manager で管理し、
  # logs/session-state などの実行時データは writable のまま運用する。
  home.file.".copilot/config.json".source = ../../home/dot_copilot/config.json;
  home.file.".copilot/mcp-config.json".source = ../../home/dot_copilot/mcp-config.json;
  home.file.".copilot/lsp-config.json".source = ../../home/dot_copilot/lsp-config.json;
  home.file.".copilot/instructions/nix-home.instructions.md".source =
    ../../home/dot_copilot/instructions/nix-home.instructions.md;

  home.activation.setupCopilotRuntimeDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    COPILOT_DIR="$HOME/.copilot"

    if [ -e "$COPILOT_DIR" ] && [ ! -d "$COPILOT_DIR" ]; then
      echo "[nix-home] Copilot path is not a directory: $COPILOT_DIR"
    else
      mkdir -p "$COPILOT_DIR/logs" "$COPILOT_DIR/session-state" "$COPILOT_DIR/ide"
    fi
  '';
}
