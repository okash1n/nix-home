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

  mkdir -p "$(dirname "$DRACULA_PRO_DIR")"
  if [ -d "$DRACULA_PRO_DIR/.git" ]; then
    echo "Updating Dracula Pro repository"
    git -C "$DRACULA_PRO_DIR" pull --ff-only
    return 0
  fi

  if [ -d "$DRACULA_PRO_DIR" ]; then
    echo "Path exists but is not a git repository: $DRACULA_PRO_DIR"
    exit 1
  fi

  echo "Cloning Dracula Pro repository to $DRACULA_PRO_DIR"
  git clone "$DRACULA_PRO_REPO" "$DRACULA_PRO_DIR"
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

sync_dracula_pro

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

NIX_CMD=(nix --extra-experimental-features "nix-command flakes")
NIX_HOME_USERNAME=${NIX_HOME_USERNAME:-$(id -un)}
export NIX_HOME_USERNAME

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
  if ! sudo -H NIX_HOME_USERNAME="$NIX_HOME_USERNAME" "${NIX_CMD[@]}" run --impure nix-darwin -- switch --impure --flake "$TARGET"; then
    if [ "$TARGET" != "$REPO_ROOT_DIR#default" ]; then
      echo "Falling back to default host"
      sudo -H NIX_HOME_USERNAME="$NIX_HOME_USERNAME" "${NIX_CMD[@]}" run --impure nix-darwin -- switch --impure --flake "$REPO_ROOT_DIR#default"
    else
      exit 1
    fi
  fi
else
  echo "Non-macOS is not supported yet."
  exit 1
fi

echo "Done"
