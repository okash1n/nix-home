{ pkgs, username, ... }:
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    git
    curl
    jq
    fzf
    ghq
    gawk
    gnugrep
    gnused
    zsh
    bash
    codex
    claude-code
    gemini-cli
  ];

  programs.home-manager.enable = true;
}
