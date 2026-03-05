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
    pnpm
    playwright-test
    rustup
    wrangler
    cloudflared
    caddy
    marp-cli
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
    deno
    go
    playwright-driver.browsers
  ]);

  xdg.enable = true;

  home.file.".bashrc".text = ''
    # VS Code 等から __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 だけ継承される場合のフォールバック
    : "''${CLAUDE_CONFIG_DIR:=$HOME/.config/claude}"
    : "''${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:=1}"
    : "''${CODEX_HOME:=$HOME/.config/codex}"
    : "''${GEMINI_CLI_HOME:=$HOME/.config/gemini}"
    : "''${HAPPY_HOME_DIR:=$HOME/.config/happy}"
    : "''${NIX_HOME_AGENT_SKILLS_DIR:=$HOME/nix-home/agent-skills}"
    : "''${VIMINIT:=source $HOME/.config/vim/vimrc}"
    export CLAUDE_CONFIG_DIR CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS CODEX_HOME GEMINI_CLI_HOME HAPPY_HOME_DIR NIX_HOME_AGENT_SKILLS_DIR VIMINIT

    if [ -d "$HOME/.local/bin" ]; then
      case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
      esac
    fi

    brew_bin=""
    if [ -x "/opt/homebrew/bin/brew" ]; then
      brew_bin="/opt/homebrew/bin/brew"
    elif [ -x "/usr/local/bin/brew" ]; then
      brew_bin="/usr/local/bin/brew"
    elif command -v brew >/dev/null 2>&1; then
      brew_bin="$(command -v brew)"
    fi

    if [ -n "$brew_bin" ]; then
      brew_prefix="$("$brew_bin" --prefix 2>/dev/null || true)"
      path_has_brew_bin=0
      if [ -n "$brew_prefix" ]; then
        case ":$PATH:" in
          *":$brew_prefix/bin:"*) path_has_brew_bin=1 ;;
        esac
      fi

      if [ -z "''${HOMEBREW_PREFIX:-}" ] || [ "$path_has_brew_bin" -eq 0 ]; then
        eval "$("$brew_bin" shellenv)"
      fi
    fi
  '';

  home.file.".bash_profile".text = ''
    if [ -f "$HOME/.bashrc" ]; then
      source "$HOME/.bashrc"
    fi
  '';

  programs.home-manager.enable = true;
}
