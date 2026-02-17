#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  uninstall_tool.sh --attr <nix-attr> [options]

Options:
  --group <pkgs|llm-agents>   Target package group (default: pkgs)
  --repo <path>               nix-home path (default: ~/nix-home)
  --verify <cmd1,cmd2,...>    Commands expected to be absent after switch
  --allow-present             Do not fail even if --verify command remains present
  --no-switch                 Run build only

Examples:
  scripts/uninstall_tool.sh --attr caddy --verify caddy
  scripts/uninstall_tool.sh --attr marp-cli --verify marp
  scripts/uninstall_tool.sh --attr codex --group llm-agents --verify codex
EOF
}

ATTR=""
GROUP="pkgs"
REPO="${NIX_HOME_REPO:-$HOME/nix-home}"
VERIFY=""
ALLOW_PRESENT=0
NO_SWITCH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --attr)
      ATTR="${2:-}"
      shift 2
      ;;
    --group)
      GROUP="${2:-}"
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
    --allow-present)
      ALLOW_PRESENT=1
      shift
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

if [[ "$GROUP" != "pkgs" && "$GROUP" != "llm-agents" ]]; then
  echo "[ERROR] --group must be pkgs or llm-agents" >&2
  exit 1
fi

REPO="$(cd "$REPO" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[step] remove package attr from nix-home: attr=$ATTR group=$GROUP repo=$REPO"
python3 "$SCRIPT_DIR/remove_package.py" --repo "$REPO" --attr "$ATTR" --group "$GROUP"

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

if [[ -z "$VERIFY" ]]; then
  echo "[info] --verify not specified, skipped absence check"
  echo "[done] uninstall flow completed"
  exit 0
fi

echo "[step] verify commands are absent"
IFS=',' read -r -a cmds <<< "$VERIFY"
for raw in "${cmds[@]}"; do
  cmd="$(echo "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -n "$cmd" ]] || continue
  if zsh -lc "command -v \"$cmd\" >/dev/null 2>&1"; then
    resolved="$(zsh -lc "command -v \"$cmd\"")"
    if [[ "$ALLOW_PRESENT" -eq 1 ]]; then
      echo "[warn] $cmd still present -> $resolved"
      continue
    fi
    echo "[ERROR] command still present after uninstall: $cmd -> $resolved" >&2
    exit 1
  fi
  echo "[ok] $cmd is absent"
done

echo "[done] uninstall flow completed"
