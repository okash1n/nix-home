{ lib, ... }:
{
  # 旧ホーム直下パスへの誤生成を早期検知するための番兵
  home.file.".claude".text = "legacy path blocked: use ~/.config/claude\n";
  home.file.".codex".text = "legacy path blocked: use ~/.config/codex\n";
  home.file.".gemini".text = "legacy path blocked: use ~/.config/gemini\n";
  home.file.".happy".text = "legacy path blocked: use ~/.config/happy\n";

  home.file.".config/AGENTS.md".source = ../../home/dot_config/AGENTS.md;
  home.file.".config/codex/AGENTS.md".source = ../../home/dot_config/AGENTS.md;
  home.file.".config/gemini/GEMINI.md".source = ../../home/dot_config/AGENTS.md;
  home.file.".config/happy/AGENTS.md".source = ../../home/dot_config/AGENTS.md;

  # Claude Code: 共通指示 + Claude 固有指示を結合
  home.file.".config/claude/CLAUDE.md".text =
    builtins.readFile ../../home/dot_config/AGENTS.md + "\n\n" +
    builtins.readFile ../../home/dot_config/claude/CLAUDE.md;

  # Claude Code の settings.json に teammateMode を設定
  home.activation.setupClaudeTeammateMode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CLAUDE_DIR="''${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}"
    SETTINGS_FILE="$CLAUDE_DIR/settings.json"

    mkdir -p "$CLAUDE_DIR"

    if ! command -v jq >/dev/null 2>&1; then
      echo "[nix-home] jq が見つからないため Claude settings の更新をスキップします。"
    elif [ ! -f "$SETTINGS_FILE" ]; then
      printf '%s\n' '{"teammateMode":"auto"}' > "$SETTINGS_FILE"
      echo "[nix-home] Claude Code: teammateMode=auto を設定しました (新規作成)"
    elif ! jq -e '.' "$SETTINGS_FILE" >/dev/null 2>&1; then
      echo "[nix-home] Claude settings.json が不正な JSON のため更新をスキップします。"
    elif jq -e '.teammateMode' "$SETTINGS_FILE" >/dev/null 2>&1; then
      :
    else
      TMP=$(mktemp)
      jq '. + {teammateMode: "auto"}' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
      echo "[nix-home] Claude Code: teammateMode=auto を設定しました"
    fi
  '';
}
