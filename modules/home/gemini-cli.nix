{ lib, ... }:
{
  # Gemini CLI の settings.json に context.fileName を設定
  home.activation.setupGeminiContext = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    GEMINI_DIR="''${GEMINI_CLI_HOME:-$HOME/.config/gemini}"
    SETTINGS_FILE="$GEMINI_DIR/settings.json"

    if [ ! -f "$SETTINGS_FILE" ]; then
      echo "[nix-home] Gemini settings.json が見つかりません。スキップします。"
    elif command -v jq >/dev/null 2>&1; then
      if ! jq -e '.context.fileName' "$SETTINGS_FILE" >/dev/null 2>&1; then
        TMP=$(mktemp)
        jq '. + {context: {fileName: ["AGENTS.md", "GEMINI.md"]}}' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
        echo "[nix-home] Gemini CLI: context.fileName を設定しました"
      fi
    fi
  '';
}
