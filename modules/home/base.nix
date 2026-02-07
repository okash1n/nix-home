{ pkgs, username, lib, ... }:
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  home.stateVersion = "24.05";

  home.packages = (with pkgs; [
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

  home.file.".config/zsh/.p10k.zsh".source = ../../home/zsh/p10k.zsh;

  home.file.".config/ghostty/config".text = ''
    # Font
    font-family = "HackGen Console NF"
    font-codepoint-map = U+3000-U+9FFF=HackGen Console NF
    font-size = 16

    # Theme (Dracula Pro)
    palette = 0=#22212C
    palette = 1=#FF9580
    palette = 2=#8AFF80
    palette = 3=#FFFF80
    palette = 4=#9580FF
    palette = 5=#FF80BF
    palette = 6=#80FFEA
    palette = 7=#F8F8F2
    palette = 8=#504C67
    palette = 9=#FFAA99
    palette = 10=#A2FF99
    palette = 11=#FFFF99
    palette = 12=#AA99FF
    palette = 13=#FF99CC
    palette = 14=#99FFEE
    palette = 15=#FFFFFF
    background = #22212C
    foreground = #F8F8F2
    cursor-color = #7970A9
    cursor-text = #7970A9
    selection-background = #454158
    selection-foreground = #F8F8F2

    # Icon
    macos-icon = "retro"
  '';

  home.activation.setupTerminalDraculaPro = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ "$(/usr/bin/uname)" = "Darwin" ]; then
      if [ "''${NIX_HOME_SKIP_TERMINAL_THEME:-0}" = "1" ] || [ -f "$HOME/.local/state/nix-home/skip-terminal-theme" ]; then
        echo "[nix-home] Skipping Terminal.app theme setup (NIX_HOME_SKIP_TERMINAL_THEME=1)."
      elif ! /usr/bin/pgrep -x WindowServer >/dev/null 2>&1; then
        echo "[nix-home] Skipping Terminal.app theme setup (no GUI session)."
      else
        DRACULA_PRO_ROOT="$HOME/ghq/github.com/okash1n/dracula-pro"
        THEME_FILE="$DRACULA_PRO_ROOT/themes/terminal-app/Dracula Pro.terminal"
        STATE_DIR="$HOME/.local/state/nix-home"
        MARKER_FILE="$STATE_DIR/terminal-dracula-pro.sha256"

        mkdir -p "$STATE_DIR"

        if [ ! -f "$THEME_FILE" ]; then
          echo "[nix-home] Dracula Pro theme file was not found: $THEME_FILE"
          echo "[nix-home] Run: ghq get git@github.com:okash1n/dracula-pro.git"
        else
          THEME_IMPORTED=1
          THEME_HASH=$(/usr/bin/shasum -a 256 "$THEME_FILE" | /usr/bin/awk '{print $1}')
          APPLIED_HASH=""
          if [ -f "$MARKER_FILE" ]; then
            APPLIED_HASH="$(cat "$MARKER_FILE" 2>/dev/null || true)"
          fi

          if [ "$THEME_HASH" != "$APPLIED_HASH" ]; then
            /usr/bin/open "$THEME_FILE" >/dev/null 2>&1 &
            for _ in 1 2 3 4 5; do
              if /usr/bin/defaults export com.apple.Terminal - 2>/dev/null | /usr/bin/grep -q "<key>Dracula Pro</key>"; then
                break
              fi
              /bin/sleep 1
            done
          fi

          if ! /usr/bin/defaults export com.apple.Terminal - 2>/dev/null | /usr/bin/grep -q "<key>Dracula Pro</key>"; then
            THEME_IMPORTED=0
            echo "[nix-home] Dracula Pro profile import could not be confirmed."
            echo "[nix-home] Please open once: $THEME_FILE"
          fi

          if [ "$THEME_IMPORTED" = "1" ]; then
            printf "%s\n" "$THEME_HASH" > "$MARKER_FILE"

            /usr/bin/defaults write com.apple.Terminal "Default Window Settings" "Dracula Pro" || true
            /usr/bin/defaults write com.apple.Terminal "Startup Window Settings" "Dracula Pro" || true
            /usr/bin/defaults write com.apple.Terminal "Window Settings"."Dracula Pro".columnCount 120 || true
            /usr/bin/defaults write com.apple.Terminal "Window Settings"."Dracula Pro".rowCount 30 || true
            /usr/bin/defaults write com.apple.Terminal "Window Settings"."Dracula Pro".FontWidthSpacing 1.0 || true
            /usr/bin/defaults write com.apple.Terminal "Window Settings"."Dracula Pro".FontHeightSpacing 1.0 || true

            /usr/bin/osascript -e 'with timeout of 5 seconds
              tell application "Terminal"
                if (count of windows) > 0 then
                  repeat with w in windows
                    repeat with t in tabs of w
                      set current settings of t to settings set "Dracula Pro"
                    end repeat
                  end repeat
                end if
              end tell
            end timeout' >/dev/null 2>&1 || true

            if ! /usr/bin/osascript -e 'with timeout of 3 seconds
              tell application "Terminal"
                set font name of settings set "Dracula Pro" to "HackGen Console NF"
                set font size of settings set "Dracula Pro" to 14
              end tell
            end timeout' >/dev/null 2>&1 && ! /usr/bin/osascript -e 'with timeout of 3 seconds
              tell application "Terminal"
                set font name of settings set "Dracula Pro" to "HackGenConsoleNF-Regular"
                set font size of settings set "Dracula Pro" to 14
              end tell
            end timeout' >/dev/null 2>&1; then
              echo "[nix-home] Terminal.app font sync failed or timed out."
            fi
          fi
        fi
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
