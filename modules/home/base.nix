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

  xdg.enable = true;

  home.file.".config/zsh/.zshrc".text = ''
    export HISTFILE="$HOME/.local/state/zsh/history"
    export HISTSIZE=50000
    export SAVEHIST=50000

    setopt HIST_IGNORE_DUPS
    setopt SHARE_HISTORY
    setopt INC_APPEND_HISTORY
    setopt AUTO_CD

    if [[ -o interactive ]]; then
      autoload -Uz compinit
      compinit

      if [ -f "${pkgs.fzf}/share/fzf/key-bindings.zsh" ]; then
        source "${pkgs.fzf}/share/fzf/key-bindings.zsh"
      fi
      if [ -f "${pkgs.fzf}/share/fzf/completion.zsh" ]; then
        source "${pkgs.fzf}/share/fzf/completion.zsh"
      fi

      source "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
      source "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
      source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"

      [[ -f "$HOME/.config/zsh/.p10k.zsh" ]] && source "$HOME/.config/zsh/.p10k.zsh"
    fi
  '';

  home.file.".config/zsh/.p10k.zsh".text = ''
    # Minimal powerlevel10k configuration.
    typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
    typeset -g POWERLEVEL9K_MODE="nerdfont-complete"
    typeset -g POWERLEVEL9K_INSTANT_PROMPT="off"

    typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs newline prompt_char)
    typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs time)
  '';

  programs.home-manager.enable = true;
}
