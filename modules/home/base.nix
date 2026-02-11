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

  home.file.".bashrc".text = ''
    # VS Code 等から __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 だけ継承される場合のフォールバック
    : "''${CLAUDE_CONFIG_DIR:=$HOME/.config/claude}"
    : "''${CODEX_HOME:=$HOME/.config/codex}"
    : "''${GEMINI_CLI_HOME:=$HOME/.config/gemini}"
    : "''${VIMINIT:=source $HOME/.config/vim/vimrc}"
    export CLAUDE_CONFIG_DIR CODEX_HOME GEMINI_CLI_HOME VIMINIT
  '';

  home.file.".bash_profile".text = ''
    if [ -f "$HOME/.bashrc" ]; then
      source "$HOME/.bashrc"
    fi
  '';

  programs.home-manager.enable = true;
}
