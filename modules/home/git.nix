{ ... }:
{
  programs.git = {
    enable = true;
    ignores = [
      "**/.claude/settings.local.json"
    ];
    settings = {
      user.name = "okash1n";
      user.email = "48118431+okash1n@users.noreply.github.com";
      init.templateDir = "~/.config/git/template";
      include.path = "~/.config/git/config";
    };
  };

  # Git template hooks (AGENTS.md -> CLAUDE.md 自動リンク)
  home.file.".config/git/template/hooks/setup-claude-symlink" = {
    source = ../../home/dot_config/git/template/hooks/setup-claude-symlink;
    executable = true;
  };
  home.file.".config/git/template/hooks/post-checkout" = {
    source = ../../home/dot_config/git/template/hooks/post-checkout;
    executable = true;
  };
  home.file.".config/git/template/hooks/post-merge" = {
    source = ../../home/dot_config/git/template/hooks/post-merge;
    executable = true;
  };
}
