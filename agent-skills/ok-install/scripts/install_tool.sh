#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install_tool.sh --attr <nix-attr> --verify <command> [options]

Options:
  --repo <path>               nix-home path (default: ~/nix-home)
  --verify <cmd1,cmd2,...>    Commands to verify with `command -v` (default: attr)
  --no-switch                 Run build only

Examples:
  scripts/install_tool.sh --attr caddy --verify caddy
  scripts/install_tool.sh --attr marp-cli --verify marp
EOF
}

ATTR=""
REPO="${NIX_HOME_REPO:-$HOME/nix-home}"
VERIFY=""
NO_SWITCH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --attr)
      ATTR="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --verify)
      VERIFY="${2:-}"
      shift 2
      ;;
    --no-switch)
      NO_SWITCH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$ATTR" ]]; then
  echo "[ERROR] --attr is required" >&2
  usage
  exit 1
fi

if [[ -z "$VERIFY" ]]; then
  VERIFY="$ATTR"
fi

REPO="$(cd "$REPO" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[step] add package attr to nix-home: attr=$ATTR repo=$REPO"
python3 "$SCRIPT_DIR/add_package.py" --repo "$REPO" --attr "$ATTR"

echo "[step] make build"
(
  cd "$REPO"
  make build
)

if [[ "$NO_SWITCH" -eq 0 ]]; then
  echo "[step] make switch"
  (
    cd "$REPO"
    make switch
  )
else
  echo "[info] --no-switch specified, skipped make switch"
fi

echo "[step] verify commands"
IFS=',' read -r -a cmds <<< "$VERIFY"
for raw in "${cmds[@]}"; do
  cmd="$(echo "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -n "$cmd" ]] || continue
  if zsh -lc "command -v \"$cmd\" >/dev/null 2>&1"; then
    resolved="$(zsh -lc "command -v \"$cmd\"")"
    echo "[ok] $cmd -> $resolved"
  else
    echo "[ERROR] command not found after apply: $cmd" >&2
    exit 1
  fi
done

echo "[done] install flow completed"
