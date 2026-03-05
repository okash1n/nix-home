#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  search_tool.sh --query <keyword> [options]

Options:
  --repo <path>         nix-home path (default: ~/nix-home)
  --no-nix-search       Skip `nix search nixpkgs`

Examples:
  scripts/search_tool.sh --query marp
  scripts/search_tool.sh --query codex
EOF
}

QUERY=""
REPO="${NIX_HOME_REPO:-$HOME/nix-home}"
NO_NIX_SEARCH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)
      QUERY="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --no-nix-search)
      NO_NIX_SEARCH=1
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

if [[ -z "$QUERY" ]]; then
  echo "[ERROR] --query is required" >&2
  usage
  exit 1
fi

REPO="$(cd "$REPO" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[section] installed in nix-home (modules/home/base.nix)"
python3 "$SCRIPT_DIR/search_package.py" --repo "$REPO" --query "$QUERY"

if [[ "$NO_NIX_SEARCH" -eq 0 ]]; then
  echo
  echo "[section] nixpkgs search: $QUERY"
  (
    cd "$REPO"
    nix --extra-experimental-features "nix-command flakes" search nixpkgs "$QUERY" || true
  )
else
  echo
  echo "[info] skipped nixpkgs search (--no-nix-search)"
fi
