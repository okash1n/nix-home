{ ... }:
{
  # 旧ホーム直下パスへの誤生成を早期検知するための番兵
  home.file.".claude".text = "legacy path blocked: use ~/.config/claude\n";
  home.file.".codex".text = "legacy path blocked: use ~/.config/codex\n";
  home.file.".gemini".text = "legacy path blocked: use ~/.config/gemini\n";

  home.file.".config/AGENTS.md".source = ../../home/dot_config/AGENTS.md;
  home.file.".config/codex/AGENTS.md".source = ../../home/dot_config/AGENTS.md;
  home.file.".config/gemini/GEMINI.md".source = ../../home/dot_config/AGENTS.md;

  # Claude Code: 共通指示 + Claude 固有指示を結合
  home.file.".config/claude/CLAUDE.md".text =
    builtins.readFile ../../home/dot_config/AGENTS.md + "\n\n" +
    builtins.readFile ../../home/dot_config/claude/CLAUDE.md;
}
