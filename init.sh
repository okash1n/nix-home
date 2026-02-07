#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_URL=${REPO_URL:-"git@github.com:okash1n/nix-home.git"}
TARGET_DIR=${NIX_HOME_DIR:-"$HOME/nix-home"}
GHQ_ROOT=${GHQ_ROOT:-"$HOME/ghq"}
DRACULA_PRO_REPO=${DRACULA_PRO_REPO:-"git@github.com:okash1n/dracula-pro.git"}
DRACULA_PRO_DIR=${DRACULA_PRO_DIR:-"$GHQ_ROOT/github.com/okash1n/dracula-pro"}
LOG_DIR="$HOME/.local/state/nix-home"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/init-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== nix-home init ==="
echo "log: $LOG_FILE"

ensure_shell_state_dirs() {
  mkdir -p "$HOME/.local/state/zsh"
  mkdir -p "$HOME/.cache/zsh"
}

ensure_shell_state_dirs

ensure_xcode_clt() {
  if [ "$(uname)" != "Darwin" ]; then
    return 0
  fi
  if /usr/bin/xcode-select -p >/dev/null 2>&1; then
    return 0
  fi

  echo "Xcode Command Line Tools are required before nix-home initialization."
  echo "Launching: xcode-select --install"
  /usr/bin/xcode-select --install >/dev/null 2>&1 || true
  echo "Complete the installation and run make init again."
  exit 1
}

ensure_github_ssh() {
  if [ "${NIX_HOME_SKIP_SSH_CHECK:-0}" = "1" ]; then
    echo "Skipping GitHub SSH check (NIX_HOME_SKIP_SSH_CHECK=1)."
    return 0
  fi
  if ! command -v ssh >/dev/null 2>&1; then
    echo "ssh command is required."
    exit 1
  fi

  local ssh_output ssh_status
  set +e
  ssh_output=$(ssh -T -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new git@github.com 2>&1)
  ssh_status=$?
  set -e

  if [ "$ssh_status" -eq 0 ] || echo "$ssh_output" | grep -qi "successfully authenticated"; then
    echo "GitHub SSH authentication is ready."
    return 0
  fi

  echo "GitHub SSH authentication is not ready."
  echo "$ssh_output"
  echo "Register your SSH public key to GitHub and retry."
  echo "Check with: ssh -T git@github.com"
  exit 1
}

sync_dracula_pro() {
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required to sync Dracula Pro repository."
    exit 1
  fi

  run_ghq() {
    if command -v ghq >/dev/null 2>&1; then
      ghq "$@"
      return 0
    fi
    if command -v nix >/dev/null 2>&1; then
      nix --extra-experimental-features "nix-command flakes" run --quiet nixpkgs#ghq -- "$@"
      return 0
    fi
    return 1
  }

  export GHQ_ROOT
  mkdir -p "$GHQ_ROOT"

  if [ -d "$DRACULA_PRO_DIR" ] && [ ! -d "$DRACULA_PRO_DIR/.git" ]; then
    echo "Path exists but is not a git repository: $DRACULA_PRO_DIR"
    exit 1
  fi

  echo "Syncing Dracula Pro repository with ghq: $DRACULA_PRO_REPO"
  if ! run_ghq get -u "$DRACULA_PRO_REPO"; then
    echo "Failed to sync Dracula Pro repository with ghq."
    echo "Run manually: GHQ_ROOT=\"$GHQ_ROOT\" ghq get -u \"$DRACULA_PRO_REPO\""
    exit 1
  fi

  if [ ! -d "$DRACULA_PRO_DIR/.git" ]; then
    echo "Dracula Pro repository was not found at expected path: $DRACULA_PRO_DIR"
    exit 1
  fi
}

ensure_xcode_clt

if command -v sudo >/dev/null 2>&1; then
  if sudo -n true >/dev/null 2>&1; then
    echo "sudo is available without prompt."
  else
    echo "Requesting sudo..."
    if [ -t 0 ]; then
      sudo -v
    else
      echo "sudo requires a password, but no TTY is available."
      echo "Run make init from an interactive terminal."
      exit 1
    fi
  fi
  (
    while true; do
      sudo -n true
      sleep 60
    done
  ) &
  SUDO_PID=$!
  trap 'kill "$SUDO_PID" >/dev/null 2>&1 || true' EXIT
fi

if [ ! -d "$REPO_ROOT_DIR/.git" ]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required to clone the repository."
    exit 1
  fi
  ensure_github_ssh
  echo "Cloning repository to $TARGET_DIR"
  git clone "$REPO_URL" "$TARGET_DIR"
  exec "$TARGET_DIR/init.sh"
fi

if command -v git >/dev/null 2>&1; then
  ensure_github_ssh
  echo "Updating repository"
  git -C "$REPO_ROOT_DIR" pull --ff-only || true
fi

ZSHENV="$HOME/.zshenv"
ZDOTDIR_LINE='export ZDOTDIR="$HOME/.config/zsh"'
if ! grep -Fq 'ZDOTDIR=' "$ZSHENV" 2>/dev/null; then
  echo "Configuring ZDOTDIR in ~/.zshenv"
  printf "%s\n" "$ZDOTDIR_LINE" >> "$ZSHENV"
fi

source_nix_profile() {
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck source=/dev/null
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    return 0
  fi
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]; then
    # shellcheck source=/dev/null
    . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
    return 0
  fi
  return 1
}

source_nix_profile || true

prepare_nix_installer_rc_backups() {
  local file backup archived ts
  ts=$(date +%Y%m%d-%H%M%S)
  for file in /etc/bashrc /etc/bash.bashrc /etc/zshrc; do
    backup="${file}.backup-before-nix"
    if ! sudo test -e "$backup"; then
      continue
    fi

    # A broken symlink (for example /etc/bashrc -> /etc/static/bashrc) will
    # make cp fail even when we need to restore the file from backup.
    if sudo test -L "$file" && ! sudo test -e "$file"; then
      sudo rm -f "$file"
      echo "Removed broken symlink: $file"
    fi

    if ! sudo test -e "$file"; then
      sudo cp "$backup" "$file"
      echo "Restored missing $file from $backup"
    fi

    archived="${backup}.nix-home-${ts}"
    sudo mv "$backup" "$archived"
    echo "Archived stale installer backup: $backup -> $archived"
  done
}

if ! command -v nix >/dev/null 2>&1; then
  prepare_nix_installer_rc_backups
  echo "Installing Nix..."
  curl -fsSL https://nixos.org/nix/install | sh -s -- --daemon --yes --no-modify-profile
  source_nix_profile || true
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "nix command is still unavailable after installation."
  exit 1
fi

sync_dracula_pro

cleanup_installer_nix_snippet() {
  local file tmp
  for file in /etc/bashrc /etc/zshrc /etc/bash.bashrc; do
    if ! sudo test -f "$file"; then
      continue
    fi
    if ! sudo grep -Fq "# Nix" "$file"; then
      continue
    fi

    tmp=$(mktemp)
    sudo awk '
      BEGIN { skip = 0 }
      /^# Nix$/ { skip = 1; next }
      /^# End Nix$/ { skip = 0; next }
      { if (!skip) print }
    ' "$file" > "$tmp"

    if ! cmp -s "$tmp" "$file"; then
      if ! sudo test -e "${file}.before-nix-home"; then
        sudo cp "$file" "${file}.before-nix-home"
      fi
      sudo cp "$tmp" "$file"
      echo "Removed installer Nix snippet from $file"
    fi
    rm -f "$tmp"
  done
}

cleanup_installer_nix_snippet

prepare_etc_for_nix_darwin() {
  local file backup
  for file in /etc/bashrc /etc/zshrc; do
    if ! sudo test -f "$file"; then
      continue
    fi
    if sudo test -L "$file"; then
      continue
    fi
    backup="${file}.before-nix-darwin"
    if sudo test -e "$backup"; then
      continue
    fi
    sudo mv "$file" "$backup"
    echo "Moved $file to $backup for first nix-darwin activation"
  done
}

prepare_etc_for_nix_darwin

ensure_nix_system_files() {
  local file
  for file in /etc/synthetic.conf /etc/fstab; do
    if sudo test -e "$file"; then
      continue
    fi
    sudo touch "$file"
    echo "Created missing $file"
  done
}

ensure_nix_system_files

maybe_open_ghostty() {
  if [ "$(uname)" != "Darwin" ]; then
    return 0
  fi
  if [ "${NIX_HOME_OPEN_GHOSTTY:-1}" != "1" ]; then
    return 0
  fi
  if [ "${NIX_HOME_SKIP_GHOSTTY_OPEN:-0}" = "1" ]; then
    return 0
  fi
  if ! /usr/bin/pgrep -x WindowServer >/dev/null 2>&1; then
    echo "[nix-home] Skipping Ghostty auto-launch (no GUI session)."
    return 0
  fi

  local marker_file ghostty_bin
  marker_file="$LOG_DIR/ghostty-auto-opened"
  if [ -f "$marker_file" ] && [ "${NIX_HOME_FORCE_OPEN_GHOSTTY:-0}" != "1" ]; then
    local marker_mtime boot_epoch
    marker_mtime=$(/usr/bin/stat -f %m "$marker_file" 2>/dev/null || echo 0)
    boot_epoch=$(/usr/sbin/sysctl -n kern.boottime 2>/dev/null | /usr/bin/awk -F'[=, ]+' '{for(i=1;i<=NF;i++) if($i=="sec"){print $(i+1); exit}}')
    boot_epoch=${boot_epoch:-0}

    if [ "$marker_mtime" -ge "$boot_epoch" ]; then
      return 0
    fi

    echo "[nix-home] Ignoring stale Ghostty auto-open marker from previous boot."
    rm -f "$marker_file"
  fi

  if /usr/bin/open -a Ghostty >/dev/null 2>&1; then
    touch "$marker_file"
    echo "[nix-home] Opened Ghostty.app."
    return 0
  fi

  if /usr/bin/open "/Applications/Nix Apps/Ghostty.app" >/dev/null 2>&1; then
    touch "$marker_file"
    echo "[nix-home] Opened Ghostty.app from /Applications/Nix Apps."
    return 0
  fi

  ghostty_bin="/etc/profiles/per-user/$NIX_HOME_USERNAME/bin/ghostty"
  if [ -x "$ghostty_bin" ]; then
    "$ghostty_bin" >/dev/null 2>&1 &
    touch "$marker_file"
    echo "[nix-home] Opened Ghostty via binary: $ghostty_bin"
    return 0
  fi

  echo "[nix-home] Ghostty is not available yet; skipping auto-launch."
}

NIX_CMD=(nix --extra-experimental-features "nix-command flakes")
NIX_HOME_USERNAME=${NIX_HOME_USERNAME:-$(id -un)}
NIX_HOME_SKIP_TERMINAL_THEME=${NIX_HOME_SKIP_TERMINAL_THEME:-0}
TERMINAL_THEME_SKIP_MARKER="$LOG_DIR/skip-terminal-theme"
export NIX_HOME_USERNAME
export NIX_HOME_SKIP_TERMINAL_THEME

if [ "$NIX_HOME_SKIP_TERMINAL_THEME" = "1" ]; then
  touch "$TERMINAL_THEME_SKIP_MARKER"
  echo "Terminal theme setup will be skipped for this run."
else
  rm -f "$TERMINAL_THEME_SKIP_MARKER"
fi

if [ ! -f "$REPO_ROOT_DIR/flake.lock" ]; then
  echo "Generating flake.lock..."
  "${NIX_CMD[@]}" flake lock "$REPO_ROOT_DIR"
fi

HOSTNAME_SHORT=$(hostname -s 2>/dev/null || hostname)
HOST_CONFIG="$REPO_ROOT_DIR/hosts/darwin/$HOSTNAME_SHORT.nix"
if [ -f "$HOST_CONFIG" ]; then
  TARGET="$REPO_ROOT_DIR#$HOSTNAME_SHORT"
else
  TARGET="$REPO_ROOT_DIR#default"
fi

if [ "$(uname)" = "Darwin" ]; then
  echo "Applying nix-darwin: $TARGET"
  if ! sudo -H NIX_HOME_USERNAME="$NIX_HOME_USERNAME" NIX_HOME_SKIP_TERMINAL_THEME="$NIX_HOME_SKIP_TERMINAL_THEME" "${NIX_CMD[@]}" run --impure nix-darwin -- switch --impure --flake "$TARGET"; then
    if [ "$TARGET" != "$REPO_ROOT_DIR#default" ]; then
      echo "Falling back to default host"
      sudo -H NIX_HOME_USERNAME="$NIX_HOME_USERNAME" NIX_HOME_SKIP_TERMINAL_THEME="$NIX_HOME_SKIP_TERMINAL_THEME" "${NIX_CMD[@]}" run --impure nix-darwin -- switch --impure --flake "$REPO_ROOT_DIR#default"
    else
      exit 1
    fi
  fi
else
  echo "Non-macOS is not supported yet."
  exit 1
fi

maybe_open_ghostty

echo "Done"
