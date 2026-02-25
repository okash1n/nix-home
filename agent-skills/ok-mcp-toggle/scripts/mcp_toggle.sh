#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_DIR="$SCRIPT_DIR/../config"
REGISTRY_FILE="${NIX_HOME_MCP_TOGGLE_REGISTRY:-$CONFIG_DIR/registry.json}"
STATE_FILE="${NIX_HOME_MCP_TOGGLE_STATE:-$CONFIG_DIR/state.json}"

SUPPORTED_CLIENTS=(claude gemini)
LEGACY_CODEX_SERVERS=(asana notion box jina)

# ---------- common ----------

die() {
  echo "[error] $*" >&2
  exit 1
}

warn() {
  echo "[warn] $*" >&2
}

info() {
  echo "[info] $*"
}

done_msg() {
  echo "[done] $*"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

now_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

ensure_jq() {
  command -v jq >/dev/null 2>&1 || die "jq が必要です"
}

project_dir_default() {
  if [ -n "${NIX_HOME_MCP_PROJECT_DIR:-}" ]; then
    printf '%s\n' "$NIX_HOME_MCP_PROJECT_DIR"
    return
  fi

  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

PROJECT_DIR="$(project_dir_default)"

ensure_project_dir() {
  [ -d "$PROJECT_DIR" ] || die "project dir が存在しません: $PROJECT_DIR"
}

project_git_root() {
  if git -C "$PROJECT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$PROJECT_DIR" rev-parse --show-toplevel
  fi
}

write_json() {
  local file="$1"
  local json="$2"
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$json" > "$tmp"
  mv "$tmp" "$file"
}

ensure_files() {
  mkdir -p "$CONFIG_DIR"

  if [ ! -f "$REGISTRY_FILE" ]; then
    cat > "$REGISTRY_FILE" <<'JSON'
{
  "version": 1,
  "servers": [
    {
      "name": "notion",
      "scope": "project",
      "auth": "oauth",
      "default_enabled": false,
      "clients_supported": ["claude", "gemini"],
      "env_requirements": [],
      "description": "Notion MCP (HTTP)",
      "template": {
        "claude": {
          "transport": "http",
          "url": "https://mcp.notion.com/mcp",
          "headers": []
        },
        "gemini": {
          "type": "http",
          "url": "https://mcp.notion.com/mcp",
          "oauth": {
            "enabled": true,
            "authorizationUrl": "https://mcp.notion.com/authorize",
            "tokenUrl": "https://mcp.notion.com/token",
            "registrationUrl": "https://mcp.notion.com/register"
          }
        }
      },
      "source": {
        "kind": "preset",
        "official_url": "https://developers.notion.com/docs/mcp"
      }
    },
    {
      "name": "asana",
      "scope": "project",
      "auth": "oauth",
      "default_enabled": false,
      "clients_supported": ["claude", "gemini"],
      "env_requirements": ["ASANA_MCP_CLIENT_ID", "ASANA_MCP_CLIENT_SECRET"],
      "description": "Asana MCP (HTTP)",
      "template": {
        "claude": {
          "transport": "http",
          "url": "https://mcp.asana.com/v2/mcp",
          "headers": [],
          "oauth": {
            "client_id_env": "ASANA_MCP_CLIENT_ID",
            "client_secret_env": "ASANA_MCP_CLIENT_SECRET",
            "callback_port": 9554
          }
        },
        "gemini": {
          "type": "http",
          "url": "https://mcp.asana.com/mcp",
          "oauth": {
            "enabled": true,
            "authorizationUrl": "https://mcp.asana.com/authorize",
            "tokenUrl": "https://mcp.asana.com/token",
            "registrationUrl": "https://mcp.asana.com/register",
            "scopes": ["default"]
          }
        }
      },
      "source": {
        "kind": "preset",
        "official_url": "https://developers.asana.com/docs/using-asanas-mcp-server"
      }
    },
    {
      "name": "box",
      "scope": "project",
      "auth": "oauth",
      "default_enabled": false,
      "clients_supported": ["claude", "gemini"],
      "env_requirements": ["BOX_MCP_CLIENT_ID", "BOX_MCP_CLIENT_SECRET"],
      "description": "Box MCP (HTTP)",
      "template": {
        "claude": {
          "transport": "http",
          "url": "https://mcp.box.com",
          "headers": [],
          "oauth": {
            "client_id_env": "BOX_MCP_CLIENT_ID",
            "client_secret_env": "BOX_MCP_CLIENT_SECRET",
            "callback_port": 9556
          }
        },
        "gemini": {
          "type": "http",
          "url": "https://mcp.box.com"
        }
      },
      "source": {
        "kind": "preset",
        "official_url": "https://developer.box.com/guides/box-ai/mcp/"
      }
    }
  ]
}
JSON
  fi

  if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" <<'JSON'
{
  "version": 1,
  "servers": {}
}
JSON
  fi

  jq -e 'type=="object" and (.servers|type=="array")' "$REGISTRY_FILE" >/dev/null || die "invalid registry"
  jq -e 'type=="object" and (.servers|type=="object")' "$STATE_FILE" >/dev/null || die "invalid state"

  jq -e '.servers | all((.scope=="global") or (.scope=="project"))' "$REGISTRY_FILE" >/dev/null \
    || die "registry scope は global/project のみ対応です"
}

usage() {
  cat <<'EOF'
Usage:
  mcp_toggle.sh list [--json]
  mcp_toggle.sh add [name] [--preset PRESET] [--scope global|project] [--default-enabled true|false] [--clients claude,gemini]
  mcp_toggle.sh remove [name ...|--all] [--scope global|project|all] [--clients claude,gemini]
  mcp_toggle.sh enable [name ...|--default|--all] [--scope global|project|all] [--clients claude,gemini] [--ignore-target gitignore|exclude|none] [--ignore-granularity mcp|client]
  mcp_toggle.sh disable [name ...|--all] [--scope global|project|all] [--clients claude,gemini]
  mcp_toggle.sh preauth [name ...|--all] [--scope global|project|all] [--clients claude,gemini]
  mcp_toggle.sh status [name ...|--all] [--scope global|project|all]

Notes:
  - 管理対象は claude / gemini です（codex 対象外）。
  - scope=global はユーザー設定、scope=project はプロジェクト設定に反映します。
  - add は常に preauth を実行し、失敗時は登録しません。
  - oauth の preauth は完全自動ではありません。必要時はクライアント側で最終認証を行ってください。
  - project scope 反映先はカレントプロジェクト（または NIX_HOME_MCP_PROJECT_DIR）です。
  - このスクリプトは非対話CLIです。暗黙選択は行いません（--clients / 対象サーバー / --ignore-target 等を明示）。
EOF
}

parse_csv_lines() {
  local raw="$1"
  local item
  IFS=',' read -r -a items <<<"$raw"
  for item in "${items[@]}"; do
    item="$(trim "$item")"
    [ -n "$item" ] || continue
    echo "$item"
  done
}

is_supported_client() {
  local c="$1"
  local s
  for s in "${SUPPORTED_CLIENTS[@]}"; do
    [ "$s" = "$c" ] && return 0
  done
  return 1
}

resolve_clients() {
  local cli_csv="${1:-}"
  local -a out=()

  [ -n "$cli_csv" ] || die "--clients が必要です"

  while IFS= read -r c; do
    is_supported_client "$c" || die "unsupported client: $c"
    out+=("$c")
  done < <(parse_csv_lines "$cli_csv")
  [ "${#out[@]}" -gt 0 ] || die "--clients is empty"
  printf '%s\n' "${out[@]}"
}

normalize_scope_filter() {
  local scope_filter="$1"
  case "$scope_filter" in
    ""|all|global|project) printf '%s\n' "${scope_filter:-all}" ;;
    *) die "scope は global/project/all のみ指定できます" ;;
  esac
}

normalize_ignore_target() {
  local value="${1:-}"
  case "$value" in
    ""|gitignore|exclude|none) printf '%s\n' "$value" ;;
    *) die "--ignore-target は gitignore|exclude|none のみ指定できます" ;;
  esac
}

normalize_ignore_granularity() {
  local value="${1:-}"
  case "$value" in
    ""|mcp|client) printf '%s\n' "${value:-mcp}" ;;
    *) die "--ignore-granularity は mcp|client のみ指定できます" ;;
  esac
}

scope_client_value() {
  local client="$1"
  local scope="$2"

  case "$scope" in
    global)
      case "$client" in
        claude) echo "user" ;;
        gemini) echo "user" ;;
        *) return 1 ;;
      esac
      ;;
    project)
      case "$client" in
        claude) echo "project" ;;
        gemini) echo "project" ;;
        *) return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

registry_has() {
  local name="$1"
  jq -e --arg name "$name" '.servers[] | select(.name==$name)' "$REGISTRY_FILE" >/dev/null
}

registry_get() {
  local name="$1"
  jq -c --arg name "$name" '.servers[] | select(.name==$name)' "$REGISTRY_FILE"
}

registry_names_by_scope() {
  local scope_filter="$(normalize_scope_filter "${1:-all}")"
  if [ "$scope_filter" = "all" ]; then
    jq -r '.servers[].name' "$REGISTRY_FILE"
  else
    jq -r --arg scope "$scope_filter" '.servers[] | select(.scope==$scope) | .name' "$REGISTRY_FILE"
  fi
}

registry_add() {
  local server_json="$1"
  write_json "$REGISTRY_FILE" "$(jq --argjson s "$server_json" '.servers += [$s]' "$REGISTRY_FILE")"
}

registry_remove() {
  local name="$1"
  write_json "$REGISTRY_FILE" "$(jq --arg name "$name" '.servers |= map(select(.name != $name))' "$REGISTRY_FILE")"
}

state_set() {
  local name="$1"
  local client="$2"
  local status="$3"
  local err="${4:-}"
  local ts
  ts="$(now_utc)"
  write_json "$STATE_FILE" "$(jq \
    --arg name "$name" \
    --arg client "$client" \
    --arg status "$status" \
    --arg err "$err" \
    --arg ts "$ts" \
    '
      .servers[$name] = (
        (.servers[$name] // {preauth_status:{claude:"unknown",gemini:"unknown"},last_preauth_at:"",last_error:""})
        | .preauth_status[$client] = $status
        | .last_preauth_at = $ts
        | .last_error = $err
      )
    ' "$STATE_FILE")"
}

state_clear() {
  local name="$1"
  write_json "$STATE_FILE" "$(jq --arg name "$name" 'del(.servers[$name])' "$STATE_FILE")"
}

state_preauth() {
  local name="$1"
  local client="$2"
  jq -r --arg name "$name" --arg client "$client" '.servers[$name].preauth_status[$client] // "unknown"' "$STATE_FILE"
}

state_error() {
  local name="$1"
  jq -r --arg name "$name" '.servers[$name].last_error // ""' "$STATE_FILE"
}

server_supports_client() {
  local server_json="$1"
  local client="$2"
  jq -e --arg c "$client" '.clients_supported | index($c) != null' >/dev/null <<<"$server_json"
}

server_env_check() {
  local server_json="$1"
  local missing=()
  local v
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    if [ -z "${!v:-}" ]; then
      missing+=("$v")
    fi
  done < <(jq -r '.env_requirements[]?' <<<"$server_json")

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "missing env: ${missing[*]}"
    return 1
  fi
  return 0
}

server_scope() {
  local server_json="$1"
  jq -r '.scope // "global"' <<<"$server_json"
}

detect_legacy_codex_servers() {
  local name
  command -v codex >/dev/null 2>&1 || return 0
  for name in "${LEGACY_CODEX_SERVERS[@]}"; do
    if codex mcp get "$name" --json >/dev/null 2>&1; then
      echo "$name"
    fi
  done
}

warn_legacy_codex_servers() {
  local -a found=()
  readarray -t found < <(detect_legacy_codex_servers)
  [ "${#found[@]}" -gt 0 ] || return 0
  warn "codex に旧MCP設定が残っています（管理対象外）: ${found[*]}"
  warn "必要なら codex から削除してください: codex mcp remove <name>"
}

# ---------- ignore helpers ----------

append_unique_line() {
  local file="$1"
  local line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  grep -Fxq "$line" "$file" || printf '%s\n' "$line" >> "$file"
}

project_ignore_patterns() {
  local granularity="$1"
  shift
  local -a clients=("$@")
  local c

  for c in "${clients[@]}"; do
    case "$c" in
      claude)
        echo ".mcp.json"
        ;;
      gemini)
        if [ "$granularity" = "client" ]; then
          echo ".gemini/"
        else
          echo ".gemini/settings.json"
        fi
        ;;
    esac
  done | awk '!seen[$0]++'
}

apply_project_ignore_policy() {
  local target="${1:-}"
  local granularity="${2:-}"
  shift 2
  local -a clients=("$@")
  local root file line

  target="$(normalize_ignore_target "$target")"
  granularity="$(normalize_ignore_granularity "$granularity")"

  [ -n "$target" ] || die "project scope では --ignore-target が必須です（gitignore|exclude|none）"

  [ "$target" = "none" ] && return 0

  if [ "$target" = "gitignore" ]; then
    root="$(project_git_root)"
    if [ -z "$root" ]; then
      file="$PROJECT_DIR/.gitignore"
    else
      file="$root/.gitignore"
    fi
  else
    root="$(project_git_root)"
    [ -n "$root" ] || die ".git/info/exclude は git 管理下でのみ利用できます"
    file="$root/.git/info/exclude"
  fi

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    append_unique_line "$file" "$line"
  done < <(project_ignore_patterns "$granularity" "${clients[@]}")

  done_msg "ignore を更新しました: $file"
}

# ---------- Claude adapter ----------

claude_run() {
  local scope="$1"
  shift
  if [ "$scope" = "project" ]; then
    ensure_project_dir
    (
      cd "$PROJECT_DIR"
      "$@"
    )
  else
    (
      cd "$HOME"
      "$@"
    )
  fi
}

claude_remove() {
  local name="$1"
  local scope="$2"
  local claude_scope

  command -v claude >/dev/null 2>&1 || return 0
  claude_scope="$(scope_client_value claude "$scope")"
  claude_run "$scope" claude mcp remove "$name" --scope "$claude_scope" >/dev/null 2>&1 || true
}

claude_add_with_retry() {
  local name="$1"
  local scope="$2"
  shift 2
  local out rc

  out="$(claude_run "$scope" "$@" 2>&1)" && return 0
  rc=$?

  if grep -qi "already exists" <<<"$out"; then
    claude_remove "$name" "$scope"
    out="$(claude_run "$scope" "$@" 2>&1)" && return 0
    rc=$?
  fi

  [ -n "$out" ] && echo "$out" >&2
  return "$rc"
}

claude_apply() {
  local name="$1"
  local server_json="$2"
  local scope="$3"
  local tmpl transport url command
  local oauth client_id_env client_secret_env callback_port client_id client_secret
  local claude_scope
  local -a args headers cmd

  command -v claude >/dev/null 2>&1 || return 1
  tmpl=$(jq -c '.template.claude // empty' <<<"$server_json")
  [ -n "$tmpl" ] || return 20

  claude_scope="$(scope_client_value claude "$scope")"
  transport=$(jq -r '.transport // ""' <<<"$tmpl")
  oauth=$(jq -c '.oauth // {}' <<<"$tmpl")
  client_id_env=$(jq -r '.client_id_env // ""' <<<"$oauth")
  client_secret_env=$(jq -r '.client_secret_env // ""' <<<"$oauth")
  callback_port=$(jq -r '.callback_port // ""' <<<"$oauth")
  client_id=""
  client_secret=""

  if [ -n "$client_id_env" ]; then
    client_id="${!client_id_env:-}"
  fi
  if [ -n "$client_secret_env" ]; then
    client_secret="${!client_secret_env:-}"
  fi

  claude_remove "$name" "$scope"

  case "$transport" in
    http|sse)
      url=$(jq -r '.url // ""' <<<"$tmpl")
      [ -n "$url" ] || return 1
      readarray -t headers < <(jq -r '.headers[]?' <<<"$tmpl")
      cmd=(claude mcp add --scope "$claude_scope" --transport "$transport" "$name" "$url")

      if [ -n "$callback_port" ] && [[ "$callback_port" =~ ^[0-9]+$ ]]; then
        cmd=(claude mcp add --scope "$claude_scope" --transport "$transport" --callback-port "$callback_port" "$name" "$url")
      fi
      if [ -n "$client_id" ]; then
        cmd=(claude mcp add --scope "$claude_scope" --transport "$transport" --client-id "$client_id" "$name" "$url")
        if [ -n "$callback_port" ] && [[ "$callback_port" =~ ^[0-9]+$ ]]; then
          cmd=(claude mcp add --scope "$claude_scope" --transport "$transport" --callback-port "$callback_port" --client-id "$client_id" "$name" "$url")
        fi
      fi
      if [ -n "$client_secret" ]; then
        cmd=(claude mcp add --scope "$claude_scope" --transport "$transport" --client-id "$client_id" --client-secret "$name" "$url")
        if [ -n "$callback_port" ] && [[ "$callback_port" =~ ^[0-9]+$ ]]; then
          cmd=(claude mcp add --scope "$claude_scope" --transport "$transport" --callback-port "$callback_port" --client-id "$client_id" --client-secret "$name" "$url")
        fi
      fi

      local h
      for h in "${headers[@]}"; do
        cmd+=(--header "$h")
      done

      if [ -n "$client_secret" ]; then
        claude_add_with_retry "$name" "$scope" env MCP_CLIENT_SECRET="$client_secret" "${cmd[@]}"
      else
        claude_add_with_retry "$name" "$scope" "${cmd[@]}"
      fi
      ;;
    stdio)
      command=$(jq -r '.command // ""' <<<"$tmpl")
      [ -n "$command" ] || return 1
      readarray -t args < <(jq -r '.args[]?' <<<"$tmpl")
      cmd=(claude mcp add --scope "$claude_scope" "$name" -- "$command")
      cmd+=("${args[@]}")
      claude_add_with_retry "$name" "$scope" "${cmd[@]}"
      ;;
    *)
      return 1
      ;;
  esac
}

claude_status() {
  local name="$1"
  local scope="$2"
  local out status_line

  if ! command -v claude >/dev/null 2>&1; then
    echo "unavailable"
    return
  fi

  if [ "$scope" = "project" ]; then
    if [ ! -f "$PROJECT_DIR/.mcp.json" ] || ! jq -e --arg name "$name" '.mcpServers[$name]' "$PROJECT_DIR/.mcp.json" >/dev/null 2>&1; then
      echo "disabled"
      return
    fi
  fi

  if ! out="$(claude_run "$scope" claude mcp get "$name" 2>/dev/null)"; then
    echo "disabled"
    return
  fi

  status_line="$(sed -n 's/^  Status: //p' <<<"$out" | head -n1 | tr '[:upper:]' '[:lower:]')"
  if [[ "$status_line" == *"needs authentication"* ]]; then
    echo "needs-auth"
  elif [[ "$status_line" == *"connected"* ]]; then
    echo "enabled"
  elif [[ "$status_line" == *"failed"* || "$status_line" == *"error"* ]]; then
    echo "failed"
  else
    echo "enabled"
  fi
}

# ---------- Gemini adapter ----------

gemini_runtime_root() {
  printf '%s\n' "${GEMINI_CLI_HOME:-$HOME/.config/gemini}"
}

gemini_runtime() {
  printf '%s/.gemini\n' "$(gemini_runtime_root)"
}

gemini_global_settings() {
  printf '%s/settings.json\n' "$(gemini_runtime)"
}

gemini_global_enablement() {
  printf '%s/mcp-server-enablement.json\n' "$(gemini_runtime)"
}

gemini_project_settings() {
  printf '%s/.gemini/settings.json\n' "$PROJECT_DIR"
}

gemini_ensure_global() {
  local runtime settings enable
  runtime="$(gemini_runtime)"
  settings="$(gemini_global_settings)"
  enable="$(gemini_global_enablement)"

  mkdir -p "$runtime"
  [ -f "$settings" ] || echo '{}' > "$settings"
  [ -f "$enable" ] || echo '{}' > "$enable"
  jq -e 'type=="object"' "$settings" >/dev/null || die "invalid gemini settings"
  jq -e 'type=="object"' "$enable" >/dev/null || die "invalid gemini enablement"
  if ! jq -e '.mcpServers | type == "object"' "$settings" >/dev/null 2>&1; then
    write_json "$settings" "$(jq '. + {mcpServers:{}}' "$settings")"
  fi
}

gemini_ensure_project() {
  local settings
  ensure_project_dir
  mkdir -p "$PROJECT_DIR/.gemini"
  settings="$(gemini_project_settings)"
  [ -f "$settings" ] || echo '{}' > "$settings"
  jq -e 'type=="object"' "$settings" >/dev/null || die "invalid project gemini settings"
  if ! jq -e '.mcpServers | type == "object"' "$settings" >/dev/null 2>&1; then
    write_json "$settings" "$(jq '. + {mcpServers:{}}' "$settings")"
  fi
}

gemini_drop_user_server() {
  local name="$1"
  local settings

  gemini_ensure_global
  settings="$(gemini_global_settings)"
  write_json "$settings" "$(jq --arg name "$name" '.mcpServers |= with_entries(select(.key != $name))' "$settings")"
}

gemini_apply() {
  local name="$1"
  local server_json="$2"
  local scope="$3"
  local tmpl settings enable

  tmpl=$(jq -c '.template.gemini // empty' <<<"$server_json")
  [ -n "$tmpl" ] || return 20

  if [ "$scope" = "global" ]; then
    gemini_ensure_global
    settings="$(gemini_global_settings)"
    enable="$(gemini_global_enablement)"
    write_json "$settings" "$(jq --arg name "$name" --argjson s "$tmpl" '.mcpServers[$name]=$s' "$settings")"
    write_json "$enable" "$(jq --arg name "$name" 'del(.[$name])' "$enable")"
    return
  fi

  # project scope は他プロジェクトへ漏れないよう、同名の user 定義を必ず除去する。
  gemini_drop_user_server "$name"

  gemini_ensure_project
  settings="$(gemini_project_settings)"
  write_json "$settings" "$(jq --arg name "$name" --argjson s "$tmpl" '.mcpServers[$name]=$s' "$settings")"

  # project scope でも global disable フラグが残ると無効化されるため解除する。
  gemini_ensure_global
  enable="$(gemini_global_enablement)"
  write_json "$enable" "$(jq --arg name "$name" 'del(.[$name])' "$enable")"
}

gemini_disable() {
  local name="$1"
  local scope="$2"
  local enable settings

  if [ "$scope" = "global" ]; then
    gemini_ensure_global
    enable="$(gemini_global_enablement)"
    write_json "$enable" "$(jq --arg name "$name" '.[$name]={enabled:false}' "$enable")"
    return
  fi

  # project scope の disable は remove と同義で扱う。
  gemini_drop_user_server "$name"
  settings="$(gemini_project_settings)"
  [ -f "$settings" ] || return 0
  write_json "$settings" "$(jq --arg name "$name" '.mcpServers |= with_entries(select(.key != $name))' "$settings")"
}

gemini_remove() {
  local name="$1"
  local scope="$2"
  local settings enable

  if [ "$scope" = "global" ]; then
    gemini_ensure_global
    settings="$(gemini_global_settings)"
    enable="$(gemini_global_enablement)"
    write_json "$settings" "$(jq --arg name "$name" '.mcpServers |= with_entries(select(.key != $name))' "$settings")"
    write_json "$enable" "$(jq --arg name "$name" 'del(.[$name])' "$enable")"
    return
  fi

  gemini_drop_user_server "$name"
  settings="$(gemini_project_settings)"
  [ -f "$settings" ] || return 0
  write_json "$settings" "$(jq --arg name "$name" '.mcpServers |= with_entries(select(.key != $name))' "$settings")"
}

gemini_has_oauth_token() {
  local name="$1"
  local server_json="$2"
  local token_file url

  token_file="$(gemini_runtime)/mcp-oauth-tokens.json"
  [ -f "$token_file" ] || return 1

  url="$(jq -r '.template.gemini.url // ""' <<<"$server_json")"
  jq -e --arg name "$name" --arg url "$url" '
    any(.[]?; (.serverName == $name) or (.mcpServerUrl == $url))
  ' "$token_file" >/dev/null 2>&1
}

gemini_status() {
  local name="$1"
  local scope="$2"
  local settings enable

  if [ "$scope" = "global" ]; then
    settings="$(gemini_global_settings)"
  else
    settings="$(gemini_project_settings)"
  fi
  enable="$(gemini_global_enablement)"

  if [ ! -f "$settings" ] || ! jq -e --arg name "$name" '.mcpServers[$name]' "$settings" >/dev/null 2>&1; then
    echo "disabled"
    return
  fi

  if [ -f "$enable" ] && jq -e --arg name "$name" '.[$name].enabled == false' "$enable" >/dev/null 2>&1; then
    echo "disabled"
  else
    echo "enabled"
  fi
}

apply_for_client() {
  local name="$1"
  local server_json="$2"
  local client="$3"
  local scope="$4"

  case "$client" in
    claude) claude_apply "$name" "$server_json" "$scope" ;;
    gemini) gemini_apply "$name" "$server_json" "$scope" ;;
    *) return 21 ;;
  esac
}

disable_for_client() {
  local name="$1"
  local client="$2"
  local scope="$3"

  case "$client" in
    claude)
      if [ "$scope" = "global" ]; then
        claude_remove "$name" "global"
      else
        claude_remove "$name" "project"
      fi
      ;;
    gemini) gemini_disable "$name" "$scope" ;;
    *) return 21 ;;
  esac
}

remove_for_client() {
  local name="$1"
  local client="$2"
  local scope="$3"

  case "$client" in
    claude) claude_remove "$name" "$scope" ;;
    gemini) gemini_remove "$name" "$scope" ;;
    *) return 21 ;;
  esac
}

status_for_client() {
  local name="$1"
  local client="$2"
  local scope="$3"

  case "$client" in
    claude) claude_status "$name" "$scope" ;;
    gemini) gemini_status "$name" "$scope" ;;
    *) echo "unknown" ;;
  esac
}

sync_state_after_apply() {
  local name="$1"
  local server_json="$2"
  local client="$3"
  local scope="$4"
  local auth cs

  auth="$(jq -r '.auth // ""' <<<"$server_json")"
  if [ "$auth" = "oauth" ]; then
    if [ "$client" = "claude" ]; then
      cs="$(claude_status "$name" "$scope")"
      if [ "$cs" = "enabled" ]; then
        state_set "$name" "$client" "ok" ""
        done_msg "$name/$client: preauth ok"
      else
        state_set "$name" "$client" "pending_user_auth" "oauth browser auth required"
        done_msg "$name/$client: preauth pending_user_auth"
      fi
      return 0
    fi

    if gemini_has_oauth_token "$name" "$server_json"; then
      state_set "$name" "$client" "ok" ""
      done_msg "$name/$client: preauth ok"
    else
      state_set "$name" "$client" "pending_user_auth" "oauth browser auth required"
      done_msg "$name/$client: preauth pending_user_auth"
    fi
    return 0
  fi

  state_set "$name" "$client" "ok" ""
  done_msg "$name/$client: preauth ok"
}

resolve_names() {
  local mode="$1"
  local scope_filter="$2"
  shift 2
  local -a names=()
  local arg server_json scope

  for arg in "$@"; do
    if [ "$arg" = "--all" ]; then
      readarray -t names < <(registry_names_by_scope "$scope_filter")
    elif [[ "$arg" == --* ]]; then
      die "unknown option: $arg"
    else
      names+=("$arg")
    fi
  done

  if [ "${#names[@]}" -eq 0 ]; then
    if [ "$mode" = "status" ]; then
      readarray -t names < <(registry_names_by_scope "$scope_filter")
    else
      die "対象サーバーを明示してください（name... または --all）"
    fi
  fi

  # 明示 scope 指定時は、scope 不一致のサーバー指定を拒否する。
  if [ "$scope_filter" != "all" ]; then
    for arg in "${names[@]}"; do
      registry_has "$arg" || continue
      server_json="$(registry_get "$arg")"
      scope="$(server_scope "$server_json")"
      [ "$scope" = "$scope_filter" ] || die "scope=$scope_filter では指定できません: $arg (scope=$scope)"
    done
  fi

  printf '%s\n' "${names[@]}" | awk '!seen[$0]++'
}

preset_from_value() {
  local value="$1"
  case "$value" in
    notion|*notion*) echo "notion" ;;
    asana|*asana*) echo "asana" ;;
    box|*box*) echo "box" ;;
    jina|*jina*) echo "jina" ;;
    *) echo "" ;;
  esac
}

build_preset() {
  local preset="$1"
  local name="$2"
  local scope="$3"
  local default_enabled="$4"

  case "$preset" in
    notion)
      jq -cn --arg name "$name" --arg scope "$scope" --argjson d "$default_enabled" '
        {
          name:$name, scope:$scope, auth:"oauth", default_enabled:$d,
          clients_supported:["claude","gemini"], env_requirements:[],
          description:"Notion MCP (HTTP)",
          template:{
            claude:{transport:"http",url:"https://mcp.notion.com/mcp",headers:[]},
            gemini:{
              type:"http",
              url:"https://mcp.notion.com/mcp",
              oauth:{
                enabled:true,
                authorizationUrl:"https://mcp.notion.com/authorize",
                tokenUrl:"https://mcp.notion.com/token",
                registrationUrl:"https://mcp.notion.com/register"
              }
            }
          },
          source:{kind:"preset",official_url:"https://developers.notion.com/docs/mcp"}
        }
      '
      ;;
    asana)
      jq -cn --arg name "$name" --arg scope "$scope" --argjson d "$default_enabled" '
        {
          name:$name, scope:$scope, auth:"oauth", default_enabled:$d,
          clients_supported:["claude","gemini"], env_requirements:["ASANA_MCP_CLIENT_ID","ASANA_MCP_CLIENT_SECRET"],
          description:"Asana MCP (HTTP)",
          template:{
            claude:{
              transport:"http",
              url:"https://mcp.asana.com/v2/mcp",
              headers:[],
              oauth:{
                client_id_env:"ASANA_MCP_CLIENT_ID",
                client_secret_env:"ASANA_MCP_CLIENT_SECRET",
                callback_port:9554
              }
            },
            gemini:{
              type:"http",
              url:"https://mcp.asana.com/mcp",
              oauth:{
                enabled:true,
                authorizationUrl:"https://mcp.asana.com/authorize",
                tokenUrl:"https://mcp.asana.com/token",
                registrationUrl:"https://mcp.asana.com/register",
                scopes:["default"]
              }
            }
          },
          source:{kind:"preset",official_url:"https://developers.asana.com/docs/using-asanas-mcp-server"}
        }
      '
      ;;
    box)
      jq -cn --arg name "$name" --arg scope "$scope" --argjson d "$default_enabled" '
        {
          name:$name, scope:$scope, auth:"oauth", default_enabled:$d,
          clients_supported:["claude","gemini"], env_requirements:["BOX_MCP_CLIENT_ID","BOX_MCP_CLIENT_SECRET"],
          description:"Box MCP (HTTP)",
          template:{
            claude:{
              transport:"http",
              url:"https://mcp.box.com",
              headers:[],
              oauth:{
                client_id_env:"BOX_MCP_CLIENT_ID",
                client_secret_env:"BOX_MCP_CLIENT_SECRET",
                callback_port:9556
              }
            },
            gemini:{type:"http",url:"https://mcp.box.com"}
          },
          source:{kind:"preset",official_url:"https://developer.box.com/guides/box-ai/mcp/"}
        }
      '
      ;;
    jina)
      jq -cn --arg name "$name" --arg scope "$scope" --argjson d "$default_enabled" '
        {
          name:$name, scope:$scope, auth:"token", default_enabled:$d,
          clients_supported:["claude","gemini"], env_requirements:["JINA_API_KEY"],
          description:"Jina MCP (HTTP read/search)",
          template:{
            claude:{
              transport:"http",
              url:"https://mcp.jina.ai/v1?include_tags=search,read&exclude_tools=search_images,search_jina_blog,capture_screenshot_url,search_web",
              headers:["Authorization: Bearer ${JINA_API_KEY}"]
            },
            gemini:{
              type:"http",
              url:"https://mcp.jina.ai/v1?include_tags=search,read&exclude_tools=search_images,search_jina_blog,capture_screenshot_url,search_web",
              headers:{Authorization:"Bearer ${JINA_API_KEY}"}
            }
          },
          source:{kind:"preset",official_url:"https://mcp.jina.ai"}
        }
      '
      ;;
    *)
      return 1
      ;;
  esac
}

validate_server_json() {
  local json="$1"
  jq -e '
    .name and (.name|type=="string") and
    ((.scope=="global") or (.scope=="project")) and
    (.auth|type=="string") and
    (.default_enabled|type=="boolean") and
    (.clients_supported|type=="array") and
    (.env_requirements|type=="array") and
    (.description|type=="string") and
    (.template|type=="object")
  ' >/dev/null <<<"$json"
}

preauth_one() {
  local name="$1"
  local server_json="$2"
  shift 2
  local -a clients=("$@")
  local client failed=0 rc err auth scope

  auth="$(jq -r '.auth // ""' <<<"$server_json")"
  scope="$(server_scope "$server_json")"

  for client in "${clients[@]}"; do
    if ! server_supports_client "$server_json" "$client"; then
      state_set "$name" "$client" "unsupported" "client not supported"
      continue
    fi

    if ! err="$(server_env_check "$server_json" 2>/dev/null)"; then
      state_set "$name" "$client" "failed" "$err"
      warn "$name/$client: $err"
      failed=1
      continue
    fi

    # project scope の preauth は設定反映を伴わず状態記録のみ行う。
    if [ "$scope" = "project" ]; then
      if [ "$auth" = "oauth" ]; then
        state_set "$name" "$client" "pending_user_auth" "oauth browser auth required on first project enable"
        done_msg "$name/$client: preauth pending_user_auth"
      else
        state_set "$name" "$client" "ok" ""
        done_msg "$name/$client: preauth ok"
      fi
      continue
    fi

    rc=0
    apply_for_client "$name" "$server_json" "$client" "$scope" || rc=$?
    if [ "$rc" -ne 0 ]; then
      if [ "$rc" -eq 20 ]; then
        state_set "$name" "$client" "unsupported" "template missing"
      else
        state_set "$name" "$client" "failed" "apply failed"
        warn "$name/$client: apply failed (rc=$rc)"
        failed=1
      fi
      continue
    fi

    sync_state_after_apply "$name" "$server_json" "$client" "$scope"
  done

  return "$failed"
}

cmd_list() {
  if [ "${1:-}" = "--json" ]; then
    jq -c --slurpfile st "$STATE_FILE" '
      .servers
      | map(. + {
          preauth_status: ($st[0].servers[.name].preauth_status // {claude:"unknown",gemini:"unknown"}),
          last_preauth_at: ($st[0].servers[.name].last_preauth_at // ""),
          last_error: ($st[0].servers[.name].last_error // "")
      })
    ' "$REGISTRY_FILE"
    return
  fi

  printf '%-14s %-8s %-6s %-7s %-14s %-14s %-36s\n' \
    "name" "scope" "auth" "default" "clients" "preauth" "description"
  printf '%-14s %-8s %-6s %-7s %-14s %-14s %-36s\n' \
    "----" "-----" "----" "-------" "-------" "-------" "-----------"

  jq -r --slurpfile st "$STATE_FILE" '
    .servers[]
    | . as $s
    | [
        $s.name,
        $s.scope,
        $s.auth,
        (if $s.default_enabled then "true" else "false" end),
        (($s.clients_supported // []) | join(",")),
        (
          ($st[0].servers[$s.name].preauth_status // {claude:"unknown",gemini:"unknown"})
          | "c:" + .claude + ",g:" + .gemini
        ),
        (
          ($s.description // "")
          | if . == "" then "-" else . end
        )
      ]
    | @tsv
  ' "$REGISTRY_FILE" | while IFS=$'\t' read -r n s a d c p desc; do
    [ "${#desc}" -gt 36 ] && desc="${desc:0:36}"
    printf '%-14s %-8s %-6s %-7s %-14s %-14s %-36s\n' \
      "$n" "$s" "$a" "$d" "$c" "$p" "$desc"
  done

  warn_legacy_codex_servers
}

cmd_status() {
  local scope_filter=""
  local -a args=()
  local names_out=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --scope)
        [ "$#" -ge 2 ] || die "--scope requires value"
        scope_filter="$(normalize_scope_filter "$2")"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  scope_filter="$(normalize_scope_filter "${scope_filter:-all}")"

  local -a names=()
  names_out="$(resolve_names status "$scope_filter" "${args[@]}")" || die "対象サーバーの解決に失敗しました"
  if [ -n "$names_out" ]; then
    readarray -t names <<<"$names_out"
  fi

  printf '%-14s %-8s %-10s %-10s %-18s %-18s %-20s\n' "name" "scope" "claude" "gemini" "preauth(c)" "preauth(g)" "last_error"
  printf '%-14s %-8s %-10s %-10s %-18s %-18s %-20s\n' "----" "-----" "------" "------" "----------" "----------" "----------"

  local name cs gs pc pg err server_json auth scope
  for name in "${names[@]}"; do
    registry_has "$name" || { warn "unknown server: $name"; continue; }
    server_json="$(registry_get "$name")"
    auth="$(jq -r '.auth // ""' <<<"$server_json")"
    scope="$(server_scope "$server_json")"

    cs="$(status_for_client "$name" claude "$scope")"
    gs="$(status_for_client "$name" gemini "$scope")"
    pc="$(state_preauth "$name" claude)"
    pg="$(state_preauth "$name" gemini)"

    if [ "$auth" = "oauth" ]; then
      if [ "$cs" = "needs-auth" ] && [ "$pc" = "ok" ]; then
        pc="pending_user_auth"
      fi
      if [ "$cs" = "enabled" ] && [ "$pc" = "pending_user_auth" ]; then
        pc="ok"
      fi
      if [ "$gs" = "enabled" ] && [ "$pg" = "pending_user_auth" ] && gemini_has_oauth_token "$name" "$server_json"; then
        pg="ok"
      fi
    fi

    err="$(state_error "$name")"
    [ "${#err}" -gt 20 ] && err="${err:0:20}"
    printf '%-14s %-8s %-10s %-10s %-18s %-18s %-20s\n' "$name" "$scope" "$cs" "$gs" "$pc" "$pg" "$err"
  done

  warn_legacy_codex_servers
}

cmd_preauth() {
  local clients_csv=""
  local scope_filter=""
  local -a args=()
  local names_out=""
  local clients_out=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --clients)
        [ "$#" -ge 2 ] || die "--clients requires value"
        clients_csv="$2"
        shift 2
        ;;
      --scope)
        [ "$#" -ge 2 ] || die "--scope requires value"
        scope_filter="$(normalize_scope_filter "$2")"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  scope_filter="$(normalize_scope_filter "${scope_filter:-all}")"

  local -a names=() clients=()
  names_out="$(resolve_names preauth "$scope_filter" "${args[@]}")" || die "対象サーバーの解決に失敗しました"
  [ -n "$names_out" ] && readarray -t names <<<"$names_out"
  clients_out="$(resolve_clients "$clients_csv")" || die "対象クライアントの解決に失敗しました"
  [ -n "$clients_out" ] && readarray -t clients <<<"$clients_out"

  local name server_json failed=0
  for name in "${names[@]}"; do
    registry_has "$name" || { warn "unknown server: $name"; failed=1; continue; }
    server_json="$(registry_get "$name")"
    preauth_one "$name" "$server_json" "${clients[@]}" || failed=1
  done

  [ "$failed" -eq 0 ] || die "preauth failed"
}

cmd_enable() {
  local clients_csv=""
  local scope_filter=""
  local ignore_target=""
  local ignore_granularity=""
  local mode="interactive"
  local -a args=()
  local names_out=""
  local clients_out=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --clients)
        [ "$#" -ge 2 ] || die "--clients requires value"
        clients_csv="$2"
        shift 2
        ;;
      --scope)
        [ "$#" -ge 2 ] || die "--scope requires value"
        scope_filter="$(normalize_scope_filter "$2")"
        shift 2
        ;;
      --ignore-target)
        [ "$#" -ge 2 ] || die "--ignore-target requires value"
        ignore_target="$(normalize_ignore_target "$2")"
        shift 2
        ;;
      --ignore-granularity)
        [ "$#" -ge 2 ] || die "--ignore-granularity requires value"
        ignore_granularity="$(normalize_ignore_granularity "$2")"
        shift 2
        ;;
      --default)
        mode="default"
        shift
        ;;
      --all)
        mode="all"
        shift
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  local -a names clients

  scope_filter="$(normalize_scope_filter "${scope_filter:-all}")"
  if [ "${#args[@]}" -eq 0 ] && [ "$mode" = "default" ]; then
    readarray -t names < <(jq -r '.servers[] | select(.scope=="global" and .default_enabled==true) | .name' "$REGISTRY_FILE")
  elif [ "${#args[@]}" -eq 0 ] && [ "$mode" = "all" ]; then
    readarray -t names < <(registry_names_by_scope "$scope_filter")
  elif [ "${#args[@]}" -eq 0 ] && [ "$mode" = "interactive" ]; then
    die "対象サーバーを明示してください（name... または --all|--default）"
  else
    names_out="$(resolve_names enable "$scope_filter" "${args[@]}")" || die "対象サーバーの解決に失敗しました"
    [ -n "$names_out" ] && readarray -t names <<<"$names_out"
  fi

  clients_out="$(resolve_clients "$clients_csv")" || die "対象クライアントの解決に失敗しました"
  [ -n "$clients_out" ] && readarray -t clients <<<"$clients_out"
  [ "${#names[@]}" -gt 0 ] || die "enable 対象がありません"

  local name server_json failed=0 rc client scope err
  local has_project=0

  for name in "${names[@]}"; do
    registry_has "$name" || { warn "unknown server: $name"; failed=1; continue; }
    server_json="$(registry_get "$name")"
    scope="$(server_scope "$server_json")"
    if [ "$scope" = "project" ]; then
      has_project=1
    fi
  done

  if [ "$has_project" -eq 1 ]; then
    apply_project_ignore_policy "$ignore_target" "$ignore_granularity" "${clients[@]}"
  fi

  for name in "${names[@]}"; do
    registry_has "$name" || { warn "unknown server: $name"; failed=1; continue; }
    server_json="$(registry_get "$name")"
    scope="$(server_scope "$server_json")"

    if ! err="$(server_env_check "$server_json" 2>/dev/null)"; then
      warn "$name: $err"
      for client in "${clients[@]}"; do
        state_set "$name" "$client" "failed" "$err"
      done
      failed=1
      continue
    fi

    for client in "${clients[@]}"; do
      if ! server_supports_client "$server_json" "$client"; then
        warn "$name: $client unsupported"
        continue
      fi
      rc=0
      apply_for_client "$name" "$server_json" "$client" "$scope" || rc=$?
      if [ "$rc" -ne 0 ]; then
        state_set "$name" "$client" "failed" "enable failed"
        warn "$name/$client: enable failed (rc=$rc)"
        failed=1
      else
        sync_state_after_apply "$name" "$server_json" "$client" "$scope"
      fi
    done
  done

  [ "$failed" -eq 0 ] || die "enable failed"
}

cmd_disable() {
  local clients_csv=""
  local scope_filter=""
  local -a args=()
  local names_out=""
  local clients_out=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --clients)
        [ "$#" -ge 2 ] || die "--clients requires value"
        clients_csv="$2"
        shift 2
        ;;
      --scope)
        [ "$#" -ge 2 ] || die "--scope requires value"
        scope_filter="$(normalize_scope_filter "$2")"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  scope_filter="$(normalize_scope_filter "${scope_filter:-all}")"

  local -a names=() clients=()
  names_out="$(resolve_names disable "$scope_filter" "${args[@]}")" || die "対象サーバーの解決に失敗しました"
  [ -n "$names_out" ] && readarray -t names <<<"$names_out"
  clients_out="$(resolve_clients "$clients_csv")" || die "対象クライアントの解決に失敗しました"
  [ -n "$clients_out" ] && readarray -t clients <<<"$clients_out"

  local name client server_json failed=0 scope
  for name in "${names[@]}"; do
    registry_has "$name" || { warn "unknown server: $name"; failed=1; continue; }
    server_json="$(registry_get "$name")"
    scope="$(server_scope "$server_json")"

    for client in "${clients[@]}"; do
      if ! server_supports_client "$server_json" "$client"; then
        continue
      fi
      if ! disable_for_client "$name" "$client" "$scope"; then
        state_set "$name" "$client" "failed" "disable failed"
        warn "$name/$client: disable failed"
        failed=1
      else
        done_msg "$name/$client disabled"
      fi
    done
  done

  [ "$failed" -eq 0 ] || die "disable failed"
}

cmd_remove() {
  local clients_csv=""
  local scope_filter=""
  local -a args=()
  local names_out=""
  local clients_out=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --clients)
        [ "$#" -ge 2 ] || die "--clients requires value"
        clients_csv="$2"
        shift 2
        ;;
      --scope)
        [ "$#" -ge 2 ] || die "--scope requires value"
        scope_filter="$(normalize_scope_filter "$2")"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  scope_filter="$(normalize_scope_filter "${scope_filter:-all}")"

  local -a names=() clients=()
  names_out="$(resolve_names remove "$scope_filter" "${args[@]}")" || die "対象サーバーの解決に失敗しました"
  [ -n "$names_out" ] && readarray -t names <<<"$names_out"
  clients_out="$(resolve_clients "$clients_csv")" || die "対象クライアントの解決に失敗しました"
  [ -n "$clients_out" ] && readarray -t clients <<<"$clients_out"

  local name client server_json failed=0 scope
  local per_server_failed
  for name in "${names[@]}"; do
    registry_has "$name" || { warn "unknown server: $name"; failed=1; continue; }
    server_json="$(registry_get "$name")"
    scope="$(server_scope "$server_json")"
    per_server_failed=0

    for client in "${clients[@]}"; do
      if ! server_supports_client "$server_json" "$client"; then
        continue
      fi
      if ! remove_for_client "$name" "$client" "$scope"; then
        warn "$name/$client: remove failed"
        per_server_failed=1
        failed=1
      else
        done_msg "$name/$client removed"
      fi
    done

    if [ "$per_server_failed" -eq 0 ]; then
      registry_remove "$name"
      state_clear "$name"
      done_msg "$name removed from registry"
    fi
  done

  [ "$failed" -eq 0 ] || die "remove failed"
}

cmd_add() {
  local name=""
  local preset=""
  local scope=""
  local default_enabled="false"
  local clients_csv=""
  local clients_out=""

  if [ "$#" -gt 0 ] && [[ ! "$1" =~ ^-- ]]; then
    name="$1"
    shift
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --preset)
        [ "$#" -ge 2 ] || die "--preset requires value"
        preset="$2"
        shift 2
        ;;
      --scope)
        [ "$#" -ge 2 ] || die "--scope requires value"
        scope="$(normalize_scope_filter "$2")"
        [ "$scope" != "all" ] || die "add の --scope は global/project のみ"
        shift 2
        ;;
      --default-enabled)
        [ "$#" -ge 2 ] || die "--default-enabled requires true|false"
        default_enabled="$2"
        shift 2
        ;;
      --clients)
        [ "$#" -ge 2 ] || die "--clients requires value"
        clients_csv="$2"
        shift 2
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done

  case "$default_enabled" in
    true|false) ;;
    *) die "--default-enabled は true|false" ;;
  esac

  [ -n "$scope" ] || die "--scope が必要です"
  [ -n "$preset" ] || die "--preset が必要です"
  [ -n "$clients_csv" ] || die "--clients が必要です"

  scope="$(normalize_scope_filter "$scope")"
  [ "$scope" != "all" ] || die "invalid scope"
  preset="$(preset_from_value "$preset")"
  [ -n "$preset" ] || die "unknown preset"
  [ -n "$name" ] || name="$preset"

  registry_has "$name" && die "already exists: $name"

  local server_json
  server_json="$(build_preset "$preset" "$name" "$scope" "$default_enabled")"
  validate_server_json "$server_json" || die "invalid server json"

  local -a clients=()
  clients_out="$(resolve_clients "$clients_csv")" || die "対象クライアントの解決に失敗しました"
  [ -n "$clients_out" ] && readarray -t clients <<<"$clients_out"

  info "add: preauth 実行中 ($name)"
  if ! preauth_one "$name" "$server_json" "${clients[@]}"; then
    warn "preauth failed. rollback client config"
    local c
    for c in "${clients[@]}"; do
      remove_for_client "$name" "$c" "$scope" || true
    done
    die "add failed"
  fi

  registry_add "$server_json"
  done_msg "$name added"
}

main() {
  local cmd="${1:-}"
  [ -n "$cmd" ] || { usage; exit 1; }
  shift || true

  case "$cmd" in
    help|-h|--help) usage; exit 0 ;;
  esac

  ensure_jq
  ensure_files

  case "$cmd" in
    list) cmd_list "$@" ;;
    add) cmd_add "$@" ;;
    remove) cmd_remove "$@" ;;
    enable) cmd_enable "$@" ;;
    disable) cmd_disable "$@" ;;
    preauth) cmd_preauth "$@" ;;
    status) cmd_status "$@" ;;
    *) usage; die "unknown command: $cmd" ;;
  esac
}

main "$@"
