{ pkgs, username, ... }:
let
  athenaiCli = pkgs.writeShellScriptBin "athenai" ''
    ATHENAI_REPO="''${ATHENAI_REPO:-$HOME/ghq/github.com/athenai-dev/athenai}"

    if [ ! -f "$ATHENAI_REPO/src/cli/index.ts" ]; then
      echo "[athenai] repository not found: $ATHENAI_REPO" >&2
      echo "[athenai] set ATHENAI_REPO to your checkout path." >&2
      exit 1
    fi

    exec bun run --cwd "$ATHENAI_REPO" src/cli/index.ts "$@"
  '';
in
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
    athenaiCli
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
    happy-coder
  ]);

  xdg.enable = true;

  home.file.".bashrc".text = ''
    # VS Code 等から __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 だけ継承される場合のフォールバック
    : "''${CLAUDE_CONFIG_DIR:=$HOME/.config/claude}"
    : "''${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:=1}"
    : "''${CODEX_HOME:=$HOME/.config/codex}"
    : "''${GEMINI_CLI_HOME:=$HOME/.config/gemini}"
    : "''${HAPPY_HOME_DIR:=$HOME/.config/happy}"
    : "''${VIMINIT:=source $HOME/.config/vim/vimrc}"
    export CLAUDE_CONFIG_DIR CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS CODEX_HOME GEMINI_CLI_HOME HAPPY_HOME_DIR VIMINIT
  '';

  home.file.".bash_profile".text = ''
    if [ -f "$HOME/.bashrc" ]; then
      source "$HOME/.bashrc"
    fi
  '';

  programs.home-manager.enable = true;
}
