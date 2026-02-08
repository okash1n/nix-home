{ pkgs, username, ... }:
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  home.stateVersion = "24.05";

  home.packages = (with pkgs; [
    git
    curl
    wget
    jq
    fzf
    fd
    ripgrep
    ghq
    gh
    gawk
    gnugrep
    gnused
    findutils
    tmux
    zellij
    dust
    yazi
    nodejs
    pnpm
    bun
    rustup
    wrangler
    cloudflared
    python3
    uv
    bind
    inetutils
    mtr
    whois
    nmap
    openssl
    zsh
    bash
    vim
    sops
    age
    ssh-to-age
  ]) ++ (with pkgs.llm-agents; [
    # AI CLI tools (from numtide/llm-agents.nix, daily updates)
    codex
    claude-code
    gemini-cli
  ]);

  xdg.enable = true;

  programs.home-manager.enable = true;
}
