#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_URL=${REPO_URL:-"git@github.com:okash1n/nix-home.git"}
TARGET_DIR=${NIX_HOME_DIR:-"$HOME/nix-home"}
LOG_DIR="$HOME/.local/state/nix-home"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/init-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== nix-home init ==="
echo "log: $LOG_FILE"

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
  echo "Cloning repository to $TARGET_DIR"
  git clone "$REPO_URL" "$TARGET_DIR"
  exec "$TARGET_DIR/init.sh"
fi

if command -v git >/dev/null 2>&1; then
  echo "Updating repository"
  git -C "$REPO_ROOT_DIR" pull --ff-only || true
fi

ZSHENV="$HOME/.zshenv"
ZDOTDIR_LINE='export ZDOTDIR="$HOME/.config/zsh"'
if ! grep -Fq 'ZDOTDIR=' "$ZSHENV" 2>/dev/null; then
  echo "Configuring ZDOTDIR in ~/.zshenv"
  printf "%s\n" "$ZDOTDIR_LINE" >> "$ZSHENV"
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "Installing Nix..."
  curl -fsSL https://nixos.org/nix/install | sh -s -- --daemon
fi

if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck source=/dev/null
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [ -e /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]; then
  # shellcheck source=/dev/null
  . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
fi

export NIX_CONFIG="experimental-features = nix-command flakes"

if [ ! -f "$REPO_ROOT_DIR/flake.lock" ]; then
  echo "Generating flake.lock..."
  nix flake lock "$REPO_ROOT_DIR"
fi

HOSTNAME_SHORT=$(hostname -s 2>/dev/null || hostname)
TARGET="$REPO_ROOT_DIR#$HOSTNAME_SHORT"

if [ "$(uname)" = "Darwin" ]; then
  echo "Applying nix-darwin: $TARGET"
  if ! nix run nix-darwin -- switch --flake "$TARGET"; then
    echo "Falling back to default host"
    nix run nix-darwin -- switch --flake "$REPO_ROOT_DIR#default"
  fi
else
  echo "Non-macOS is not supported yet."
  exit 1
fi

echo "Done"
