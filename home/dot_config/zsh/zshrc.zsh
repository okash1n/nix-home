mkdir -p "$HOME/.local/state/zsh"
mkdir -p "$HOME/.cache/zsh"

export HISTFILE="$HOME/.local/state/zsh/history"
export HISTSIZE=50000
export SAVEHIST=50000

setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt AUTO_CD

if [ -f "$HOME/.config/zsh/aliases.zsh" ]; then
  source "$HOME/.config/zsh/aliases.zsh"
fi
if [ -f "$HOME/.config/zsh/functions.zsh" ]; then
  source "$HOME/.config/zsh/functions.zsh"
fi

if [[ -o interactive ]]; then
  source "$HOME/.config/zsh/nix-paths.zsh"

  autoload -Uz compinit
  compinit

  if [ -f "$NIX_FZF_SHARE/key-bindings.zsh" ]; then
    source "$NIX_FZF_SHARE/key-bindings.zsh"
  fi
  if [ -f "$NIX_FZF_SHARE/completion.zsh" ]; then
    source "$NIX_FZF_SHARE/completion.zsh"
  fi

  source "$NIX_ZSH_AUTOSUGGESTIONS"
  source "$NIX_ZSH_SYNTAX_HIGHLIGHTING"

  prompt_mode="${NIX_HOME_ZSH_PROMPT:-p10k}"
  if [ "$prompt_mode" = "hanabi" ]; then
    if [ -f "$HOME/.config/zsh/hanabi.zsh-theme" ]; then
      source "$HOME/.config/zsh/hanabi.zsh-theme"
    else
      source "$NIX_ZSH_POWERLEVEL10K"
      [[ -f "$HOME/.config/zsh/.p10k.zsh" ]] && source "$HOME/.config/zsh/.p10k.zsh"
      if [[ -f "$HOME/.config/zsh/hanabi.p10k.zsh" ]]; then
        source "$HOME/.config/zsh/hanabi.p10k.zsh"
        (( $+functions[p10k] )) && p10k reload
      fi
    fi
  else
    source "$NIX_ZSH_POWERLEVEL10K"
    [[ -f "$HOME/.config/zsh/.p10k.zsh" ]] && source "$HOME/.config/zsh/.p10k.zsh"
    if [[ -f "$HOME/.config/zsh/hanabi.p10k.zsh" ]]; then
      source "$HOME/.config/zsh/hanabi.p10k.zsh"
      (( $+functions[p10k] )) && p10k reload
    fi
  fi
fi
