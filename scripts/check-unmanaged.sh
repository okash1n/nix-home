#!/usr/bin/env bash
# Nix (home-manager) で管理されていないファイルを検出するスクリプト
#
# 検査対象:
#   1. $HOME 直下の dotfiles（.で始まるファイル・ディレクトリ）
#   2. $HOME/.config 配下すべて
#
# Usage: ./scripts/check-unmanaged.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IGNORE_FILE="${SCRIPT_DIR}/.unmanaged-ignore"

# 色付け
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# ignore パターンを読み込み（コメント・空行除外）
load_ignore_patterns() {
  if [[ -f "$IGNORE_FILE" ]]; then
    grep -v '^#' "$IGNORE_FILE" | grep -v '^$' || true
  fi
}

# ファイルが ignore パターンにマッチするかチェック
is_ignored() {
  local file="$1"
  local patterns
  patterns=$(load_ignore_patterns)

  [[ -z "$patterns" ]] && return 1

  while IFS= read -r pattern; do
    # glob パターンとしてマッチング
    if [[ "$file" == $pattern ]]; then
      return 0
    fi
  done <<< "$patterns"
  return 1
}

# Nix 管理下かチェック（/nix/store へのシンボリックリンク）
is_nix_managed() {
  local file="$1"
  if [[ -L "$file" ]]; then
    local target
    target=$(readlink "$file")
    [[ "$target" == /nix/store/* ]] && return 0
  fi
  return 1
}

# ファイルを検査
check_file() {
  local file="$1"

  # Nix 管理下なら skip
  if is_nix_managed "$file"; then
    return 0
  fi

  # ignore パターンにマッチなら skip
  if is_ignored "$file"; then
    ignored_count=$((ignored_count + 1))
    return 0
  fi

  echo -e "${YELLOW}unmanaged:${NC} $file"
  unmanaged_count=$((unmanaged_count + 1))
}

echo -e "${GREEN}Checking for unmanaged dotfiles...${NC}"
echo ""

unmanaged_count=0
ignored_count=0

# 1. $HOME 直下の dotfiles（.で始まるファイル・シンボリックリンク、depth=1）
echo -e "${GREEN}[1/2] \$HOME 直下の dotfiles${NC}"
while IFS= read -r file; do
  check_file "$file"
done < <(fd --max-depth 1 --hidden --no-ignore --type f --type l '^\.' "$HOME" 2>/dev/null)

# 2. $HOME/.config 配下すべて
echo -e "${GREEN}[2/2] \$HOME/.config 配下${NC}"
if [[ -d "$HOME/.config" ]]; then
  while IFS= read -r file; do
    check_file "$file"
  done < <(fd --hidden --no-ignore --type f --type l . "$HOME/.config" 2>/dev/null)
fi

echo ""
echo -e "${GREEN}Summary:${NC}"
echo "  Unmanaged files: $unmanaged_count"
echo "  Ignored files:   $ignored_count"

if [[ $unmanaged_count -gt 0 ]]; then
  echo ""
  echo -e "${YELLOW}Hint:${NC} Add patterns to ${IGNORE_FILE} to ignore expected unmanaged files."
fi
