#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

SECRETS_FILE="${SECRETS_FILE:-$REPO_ROOT/secrets/secrets.yaml}"
SOPS_NIX_FILE="${SOPS_NIX_FILE:-$REPO_ROOT/modules/home/sops.nix}"
SSH_KEY_PATH="${SOPS_SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"

ENV_NAME=""
SOPS_KEY=""
DRY_RUN=0
AUTO_SWITCH=""

usage() {
  cat <<'EOF'
使い方:
  scripts/set-sops-env.sh [オプション]

オプション:
  --env NAME        追加する環境変数名 (例: VSCE_PAT)
  --key NAME        secrets.yaml 側のキー名を上書き (既定: env名から自動生成)
  --ssh-key PATH    復号に使う SSH 秘密鍵 (既定: ~/.ssh/id_ed25519)
  --dry-run         ファイル更新を行わず、実行内容だけ表示
  --switch          最後に make switch を実行
  --no-switch       最後の make switch を実行しない
  -h, --help        このヘルプを表示

補足:
  - 値は対話入力で受け取り、画面に表示されます。
  - secrets/secrets.yaml と modules/home/sops.nix を同時更新します。
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "必要なコマンドが見つかりません: $cmd" >&2
    exit 1
  fi
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local input=""
  local normalized=""

  read -r -p "$prompt " input
  if [[ -z "$input" ]]; then
    input="$default"
  fi
  normalized=$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')
  case "$normalized" in
    y|yes) return 0 ;;
    n|no) return 1 ;;
    *)
      echo "y か n で入力してください。" >&2
      return 1
      ;;
  esac
}

derive_key_from_env() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}

read_secret_value() {
  local first=""
  local second=""

  while true; do
    read -r -p "${ENV_NAME} の値を入力: " first
    if [[ -z "$first" ]]; then
      echo "空文字は設定できません。"
      continue
    fi

    read -r -p "確認のため再入力: " second
    if [[ "$first" == "$second" ]]; then
      printf '%s\n' "$first"
      return 0
    fi
    echo "入力値が一致しません。再入力してください。"
  done
}

ensure_secret_declaration() {
  local line="    secrets.${SOPS_KEY} = {};"
  local tmp_file=""

  if grep -Fqx "$line" "$SOPS_NIX_FILE"; then
    return 0
  fi

  tmp_file=$(mktemp)
  awk -v newline="$line" '
    {
      lines[NR] = $0
      if ($0 ~ /^[[:space:]]*secrets\.[a-z0-9-]+[[:space:]]*=[[:space:]]*\{\};[[:space:]]*$/) {
        last_secret = NR
      }
      if (template_start == 0 && $0 ~ /templates\."sops-env\.sh"[[:space:]]*=[[:space:]]*\{/) {
        template_start = NR
      }
    }
    END {
      for (i = 1; i <= NR; i++) {
        if (last_secret == 0 && template_start > 0 && i == template_start) {
          print newline
          inserted = 1
        }
        print lines[i]
        if (last_secret > 0 && i == last_secret) {
          print newline
          inserted = 1
        }
      }
      if (!inserted) {
        print newline
      }
    }
  ' "$SOPS_NIX_FILE" > "$tmp_file"

  if (( DRY_RUN )); then
    echo "[dry-run] 追加予定: $line"
    rm -f "$tmp_file"
  else
    mv "$tmp_file" "$SOPS_NIX_FILE"
  fi
}

ensure_export_line() {
  local line="export ${ENV_NAME}=\"\${config.sops.placeholder.${SOPS_KEY}}\""
  local tmp_file=""

  if grep -Fqx "$line" "$SOPS_NIX_FILE"; then
    return 0
  fi

  tmp_file=$(mktemp)
  awk -v newline="$line" '
    {
      if (!inserted && in_content && $0 ~ /^[[:space:]]*\047\047;[[:space:]]*$/) {
        print newline
        inserted = 1
      }
      print

      if ($0 ~ /templates\."sops-env\.sh"[[:space:]]*=[[:space:]]*\{/) {
        in_template = 1
      }
      if (in_template && $0 ~ /content[[:space:]]*=[[:space:]]*\047\047/) {
        in_content = 1
      }
      if (in_template && $0 ~ /^[[:space:]]*\};[[:space:]]*$/) {
        in_template = 0
      }
    }
    END {
      if (!inserted) {
        exit 2
      }
    }
  ' "$SOPS_NIX_FILE" > "$tmp_file"

  if (( DRY_RUN )); then
    echo "[dry-run] 追加予定: $line"
    rm -f "$tmp_file"
  else
    mv "$tmp_file" "$SOPS_NIX_FILE"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="${2:-}"
      shift 2
      ;;
    --key)
      SOPS_KEY="${2:-}"
      shift 2
      ;;
    --ssh-key)
      SSH_KEY_PATH="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --switch)
      AUTO_SWITCH="yes"
      shift
      ;;
    --no-switch)
      AUTO_SWITCH="no"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "不明なオプション: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd sops
require_cmd ssh-to-age
require_cmd jq
require_cmd awk

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "secrets ファイルが見つかりません: $SECRETS_FILE" >&2
  exit 1
fi
if [[ ! -f "$SOPS_NIX_FILE" ]]; then
  echo "sops.nix が見つかりません: $SOPS_NIX_FILE" >&2
  exit 1
fi
if [[ ! -f "$SSH_KEY_PATH" ]]; then
  echo "SSH 秘密鍵が見つかりません: $SSH_KEY_PATH" >&2
  exit 1
fi

if [[ -z "$ENV_NAME" ]]; then
  read -r -p "環境変数名を入力してください (例: VSCE_PAT): " ENV_NAME
fi
if [[ ! "$ENV_NAME" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
  echo "環境変数名の形式が不正です: $ENV_NAME" >&2
  echo "利用可能: 英大文字, 数字, アンダースコア (先頭は英大文字)" >&2
  exit 1
fi

if [[ -z "$SOPS_KEY" ]]; then
  SOPS_KEY="$(derive_key_from_env "$ENV_NAME")"
fi
if [[ ! "$SOPS_KEY" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "sops キー名の形式が不正です: $SOPS_KEY" >&2
  echo "利用可能: 英小文字, 数字, ハイフン (先頭は英小文字/数字)" >&2
  exit 1
fi

echo
echo "設定対象:"
echo "  env:  $ENV_NAME"
echo "  key:  $SOPS_KEY"
echo "  file: $SECRETS_FILE"
echo "  nix:  $SOPS_NIX_FILE"
echo

if ! ask_yes_no "この内容で続行しますか? [Y/n]" "y"; then
  echo "中止しました。"
  exit 0
fi

SECRET_VALUE="$(read_secret_value)"
VALUE_JSON="$(printf '%s' "$SECRET_VALUE" | jq -Rs .)"
unset SECRET_VALUE

AGE_KEY_FILE=$(mktemp)
trap 'rm -f "$AGE_KEY_FILE"' EXIT
ssh-to-age -private-key -i "$SSH_KEY_PATH" > "$AGE_KEY_FILE"

if (( DRY_RUN )); then
  echo "[dry-run] secrets 更新予定: $SOPS_KEY"
else
  printf '%s' "$VALUE_JSON" | SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops set --value-stdin "$SECRETS_FILE" "[\"$SOPS_KEY\"]"
fi

ensure_secret_declaration
ensure_export_line

echo
echo "更新完了:"
echo "  - secrets/secrets.yaml"
echo "  - modules/home/sops.nix"

if (( DRY_RUN )); then
  echo "[dry-run] make switch は実行していません。"
  exit 0
fi

if [[ -z "$AUTO_SWITCH" ]]; then
  if ask_yes_no "このまま make switch を実行しますか? [Y/n]" "y"; then
    AUTO_SWITCH="yes"
  else
    AUTO_SWITCH="no"
  fi
fi

if [[ "$AUTO_SWITCH" == "yes" ]]; then
  (cd "$REPO_ROOT" && make switch)
else
  echo "必要に応じて手動で実行してください: make build && make switch"
fi
