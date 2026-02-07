{ pkgs, username, lib, ... }:
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
    gawk
    gnugrep
    gnused
    tmux
    nodejs
    pnpm
    bun
    python3
    uv
    zsh
    bash
    vim
    codex
    claude-code
    gemini-cli
  ]);

  xdg.enable = true;

  home.file.".config/zsh/.zshrc".text = ''
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

      if [ "''${NIX_HOME_ZSH_PROMPT:-hanabi}" = "p10k" ]; then
        source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
        [[ -f "$HOME/.config/zsh/.p10k.zsh" ]] && source "$HOME/.config/zsh/.p10k.zsh"
        [[ -f "$HOME/.config/zsh/hanabi.p10k.zsh" ]] && source "$HOME/.config/zsh/hanabi.p10k.zsh"
      else
        if [ -f "$HOME/.config/zsh/hanabi.zsh-theme" ]; then
          source "$HOME/.config/zsh/hanabi.zsh-theme"
        else
          # Fallback to p10k when Hanabi theme file is missing.
          source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
          [[ -f "$HOME/.config/zsh/.p10k.zsh" ]] && source "$HOME/.config/zsh/.p10k.zsh"
          [[ -f "$HOME/.config/zsh/hanabi.p10k.zsh" ]] && source "$HOME/.config/zsh/hanabi.p10k.zsh"
        fi
      fi
    fi
  '';

  home.file.".config/zsh/.p10k.zsh".source = ../../home/zsh/p10k.zsh;
  home.file.".config/zsh/aliases.zsh".source = ../../home/zsh/aliases.zsh;
  home.file.".config/zsh/functions.zsh".source = ../../home/zsh/functions.zsh;

  home.file.".config/ghostty/config".text = ''
    # Font
    font-family = "HackGen Console NF"
    font-codepoint-map = U+3000-U+9FFF=HackGen Console NF
    font-size = 16

    # Theme
    theme = hanabi

    # Icon
    macos-icon = "retro"
  '';

  home.file.".vimrc".text = ''
    set termguicolors
    syntax on
    colorscheme hanabi
  '';

  home.activation.setupHanabiThemeAssets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    HANABI_ROOT="$HOME/ghq/github.com/hanabi-works/hanabi-theme"

    if [ ! -d "$HANABI_ROOT/.git" ]; then
      echo "[nix-home] hanabi-theme is not available: $HANABI_ROOT"
      echo "[nix-home] Run: ghq get -u https://github.com/hanabi-works/hanabi-theme.git"
    else
      mkdir -p "$HOME/.config/ghostty/themes" "$HOME/.config/zsh" "$HOME/.vim/colors"

      if [ -f "$HANABI_ROOT/themes/ghostty/hanabi" ]; then
        cp -f "$HANABI_ROOT/themes/ghostty/hanabi" "$HOME/.config/ghostty/themes/hanabi"
      fi
      if [ -f "$HANABI_ROOT/themes/zsh/hanabi.zsh-theme" ]; then
        cp -f "$HANABI_ROOT/themes/zsh/hanabi.zsh-theme" "$HOME/.config/zsh/hanabi.zsh-theme"
      fi
      if [ -f "$HANABI_ROOT/themes/zsh/hanabi.p10k.zsh" ]; then
        cp -f "$HANABI_ROOT/themes/zsh/hanabi.p10k.zsh" "$HOME/.config/zsh/hanabi.p10k.zsh"
      fi
      if [ -f "$HANABI_ROOT/themes/vim/colors/hanabi.vim" ]; then
        cp -f "$HANABI_ROOT/themes/vim/colors/hanabi.vim" "$HOME/.vim/colors/hanabi.vim"
      fi
    fi
  '';

  home.activation.setupTerminalHanabi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ "$(/usr/bin/uname)" = "Darwin" ]; then
      if [ "''${NIX_HOME_SKIP_TERMINAL_THEME:-0}" = "1" ] || [ -f "$HOME/.local/state/nix-home/skip-terminal-theme" ]; then
        echo "[nix-home] Skipping Terminal.app theme setup (NIX_HOME_SKIP_TERMINAL_THEME=1)."
      elif ! /usr/bin/pgrep -x WindowServer >/dev/null 2>&1; then
        echo "[nix-home] Skipping Terminal.app theme setup (no GUI session)."
      else
        HANABI_ROOT="$HOME/ghq/github.com/hanabi-works/hanabi-theme"
        THEME_FILE="$HANABI_ROOT/themes/terminal-app/Hanabi.terminal"
        STATE_DIR="$HOME/.local/state/nix-home"
        MARKER_FILE="$STATE_DIR/terminal-hanabi.sha256"

        mkdir -p "$STATE_DIR"

        if [ ! -f "$THEME_FILE" ]; then
          echo "[nix-home] Hanabi theme file was not found: $THEME_FILE"
          echo "[nix-home] Run: ghq get -u https://github.com/hanabi-works/hanabi-theme.git"
        else
          THEME_IMPORTED=1
          THEME_HASH=$(/usr/bin/shasum -a 256 "$THEME_FILE" | /usr/bin/awk '{print $1}')
          APPLIED_HASH=""
          FONT_APPLIED=0

          ensure_terminal_ready() {
            /usr/bin/open -a Terminal >/dev/null 2>&1 || true
            for _ in 1 2 3 4 5 6; do
              if /usr/bin/osascript -e 'with timeout of 2 seconds
                tell application "Terminal"
                  return (count of settings sets) as string
                end tell
              end timeout' >/dev/null 2>&1; then
                return 0
              fi
              /bin/sleep 1
            done
            return 1
          }

          terminal_has_hanabi_profile() {
            /usr/bin/osascript -e 'with timeout of 3 seconds
              tell application "Terminal"
                return (exists settings set "Hanabi") as string
              end tell
            end timeout' 2>/dev/null | /usr/bin/tr -d '\r' | /usr/bin/grep -qi "^true$"
          }

          apply_terminal_font() {
            local font_name current_font
            for font_name in \
              "HackGen Console NF" \
              "HackGen35 Console NF" \
              "HackGenConsoleNF-Regular" \
              "HackGen35ConsoleNF-Regular"
            do
              /usr/bin/osascript >/dev/null 2>&1 <<OSA || true
with timeout of 5 seconds
  tell application "Terminal"
    set font name of settings set "Hanabi" to "$font_name"
    set font size of settings set "Hanabi" to 14
  end tell
end timeout
OSA

              current_font=$(/usr/bin/osascript -e 'with timeout of 3 seconds
                tell application "Terminal"
                  return font name of settings set "Hanabi"
                end tell
              end timeout' 2>/dev/null | /usr/bin/tr -d '\r')

              if [ "$current_font" = "$font_name" ]; then
                echo "[nix-home] Terminal.app font applied: $font_name"
                return 0
              fi
            done
            return 1
          }

          set_terminal_default_profile() {
            local current_default

            /usr/bin/osascript >/dev/null 2>&1 <<'OSA' || true
with timeout of 5 seconds
  tell application "Terminal"
    set default settings to settings set "Hanabi"
    set startup settings to settings set "Hanabi"
  end tell
end timeout
OSA

            /usr/bin/defaults write com.apple.Terminal "Default Window Settings" "Hanabi" || true
            /usr/bin/defaults write com.apple.Terminal "Startup Window Settings" "Hanabi" || true

            current_default=$(/usr/bin/defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || true)
            if [ "$current_default" != "Hanabi" ]; then
              echo "[nix-home] Terminal default profile is '$current_default' (expected Hanabi)."
              return 1
            fi
            return 0
          }

          if [ -f "$MARKER_FILE" ]; then
            APPLIED_HASH="$(cat "$MARKER_FILE" 2>/dev/null || true)"
          fi

          if ! ensure_terminal_ready; then
            THEME_IMPORTED=0
            echo "[nix-home] Terminal.app is not ready for automation."
          fi

          if [ "$THEME_IMPORTED" = "1" ] && { [ "$THEME_HASH" != "$APPLIED_HASH" ] || ! terminal_has_hanabi_profile; }; then
            /usr/bin/open "$THEME_FILE" >/dev/null 2>&1 &
            for _ in 1 2 3 4 5 6 7 8; do
              if terminal_has_hanabi_profile; then
                break
              fi
              /bin/sleep 1
            done
          fi

          if [ "$THEME_IMPORTED" = "1" ] && ! terminal_has_hanabi_profile; then
            THEME_IMPORTED=0
            echo "[nix-home] Hanabi profile import could not be confirmed."
            echo "[nix-home] Please open once: $THEME_FILE"
          fi

          if [ "$THEME_IMPORTED" = "1" ]; then
            printf "%s\n" "$THEME_HASH" > "$MARKER_FILE"

            if ! set_terminal_default_profile; then
              echo "[nix-home] Terminal default profile sync failed."
            fi
            /usr/bin/defaults write com.apple.Terminal "Window Settings"."Hanabi".columnCount 120 || true
            /usr/bin/defaults write com.apple.Terminal "Window Settings"."Hanabi".rowCount 30 || true
            /usr/bin/defaults write com.apple.Terminal "Window Settings"."Hanabi".FontWidthSpacing 1.0 || true
            /usr/bin/defaults write com.apple.Terminal "Window Settings"."Hanabi".FontHeightSpacing 1.0 || true

            if apply_terminal_font; then
              FONT_APPLIED=1
            fi

            /usr/bin/osascript -e 'with timeout of 5 seconds
              tell application "Terminal"
                if (count of windows) > 0 then
                  repeat with w in windows
                    repeat with t in tabs of w
                      set current settings of t to settings set "Hanabi"
                    end repeat
                  end repeat
                end if
              end tell
            end timeout' >/dev/null 2>&1 || true

            if [ "$FONT_APPLIED" != "1" ]; then
              echo "[nix-home] Terminal.app font sync failed (HackGen candidates were not applied)."
            fi
          fi
        fi
      fi
    fi
  '';

  home.activation.setupVSCodeHanabiTheme = lib.hm.dag.entryAfter [ "installPackages" ] ''
    CODE_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
    CODE_SETTINGS_FILE="$CODE_SETTINGS_DIR/settings.json"

    USERNAME="$(/usr/bin/id -un 2>/dev/null || true)"
    PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USERNAME/bin:$PATH"

    if ! command -v code >/dev/null 2>&1; then
      echo "[nix-home] code command was not found; skipping VS Code theme setup."
    elif ! /usr/bin/pgrep -x WindowServer >/dev/null 2>&1; then
      echo "[nix-home] Skipping VS Code theme setup (no GUI session)."
    else
      if ! code --list-extensions 2>/dev/null | /usr/bin/grep -q '^okash1n\\.hanabi-theme-vscode$'; then
        if ! code --install-extension okash1n.hanabi-theme-vscode --force >/dev/null 2>&1; then
          echo "[nix-home] Failed to install VS Code extension: okash1n.hanabi-theme-vscode"
        fi
      fi

      mkdir -p "$CODE_SETTINGS_DIR"

      if command -v python3 >/dev/null 2>&1; then
        python3 - "$CODE_SETTINGS_FILE" <<'PY' || true
import json
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = {}
if path.exists():
    try:
        raw = path.read_text(encoding="utf-8")
        data = json.loads(raw) if raw.strip() else {}
        if not isinstance(data, dict):
            data = {}
    except Exception:
        bak = path.with_suffix(path.suffix + ".nix-home-bak")
        try:
            path.rename(bak)
        except Exception:
            pass
        data = {}

data["workbench.colorTheme"] = "Hanabi"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
      else
        echo "[nix-home] python3 was not found; skipping VS Code settings.json update."
      fi
    fi
  '';

  programs.git = {
    enable = true;
    ignores = [
      "**/.claude/settings.local.json"
    ];
  };

  home.file.".gitconfig".text = ''
    [user]
      name = okash1n
      email = 48118431+okash1n@users.noreply.github.com
    [include]
      path = /Users/${username}/.config/git/config
  '';

  programs.home-manager.enable = true;
}
