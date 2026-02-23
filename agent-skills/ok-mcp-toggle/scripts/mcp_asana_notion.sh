#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
NIX_HOME_REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
MCP_SETUP_SCRIPTS=(
  "$NIX_HOME_REPO_ROOT/scripts/setup-codex-mcp.sh"
  "$NIX_HOME_REPO_ROOT/scripts/setup-claude-mcp.sh"
  "$NIX_HOME_REPO_ROOT/scripts/setup-gemini-mcp.sh"
)
DEFAULT_TARGET_EXCLUDE_RAW="${NIX_HOME_MCP_TOGGLE_DEFAULT_EXCLUDE:-jina,claude-mem}"
GLOBAL_CLAUDE_MEM_MCP_SERVER="${NIX_HOME_GLOBAL_CLAUDE_MEM_MCP_SERVER:-${NIX_HOME_GLOBAL_CLAUDE_CONFIG_DIR:-$HOME/.config/claude}/plugins/marketplaces/thedotmack/plugin/scripts/mcp-server.cjs}"
MANAGED_SERVERS=()
DEFAULT_TARGET_SERVERS=()
SELECTED_SERVERS=()

resolve_project_root() {
  if [ -n "${NIX_HOME_MCP_PROJECT_DIR:-}" ]; then
    (cd "$NIX_HOME_MCP_PROJECT_DIR" && pwd -P)
    return 0
  fi

  if command -v git >/dev/null 2>&1 && git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$PWD" rev-parse --show-toplevel
    return 0
  fi

  pwd -P
}

resolve_project_config_base() {
  if [ -n "${NIX_HOME_MCP_PROJECT_STATE_DIR:-}" ]; then
    case "$NIX_HOME_MCP_PROJECT_STATE_DIR" in
      /*) printf '%s\n' "$NIX_HOME_MCP_PROJECT_STATE_DIR" ;;
      *) printf '%s\n' "$PROJECT_ROOT/$NIX_HOME_MCP_PROJECT_STATE_DIR" ;;
    esac
    return 0
  fi

  if command -v git >/dev/null 2>&1 && git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    local git_dir_abs
    git_dir_abs="$(git -C "$PROJECT_ROOT" rev-parse --absolute-git-dir)"
    printf '%s\n' "$git_dir_abs/nix-home-mcp"
    return 0
  fi

  printf '%s\n' "$PROJECT_ROOT/.nix-home/mcp"
}

PROJECT_ROOT="$(resolve_project_root)"
PROJECT_CONFIG_BASE="$(resolve_project_config_base)"
PROJECT_CLAUDE_CONFIG_DIR="$PROJECT_CONFIG_BASE/claude"
PROJECT_CODEX_HOME="$PROJECT_CONFIG_BASE/codex"
PROJECT_GEMINI_CLI_HOME="$PROJECT_CONFIG_BASE/gemini"
PROJECT_ENV_FILE="$PROJECT_ROOT/.nix-home/mcp-project.env"

usage() {
  cat <<'EOF'
Usage:
  mcp_asana_notion.sh on [--all|server...]
  mcp_asana_notion.sh off [--all|server...]
  mcp_asana_notion.sh status [--all|server...]
  mcp_asana_notion.sh login [--all|server...]
  mcp_asana_notion.sh servers
  mcp_asana_notion.sh paths
EOF
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

csv_to_lines() {
  local raw="${1:-}"
  local item

  IFS=',' read -r -a items <<<"$raw"
  for item in "${items[@]}"; do
    item="$(trim "$item")"
    if [ -n "$item" ]; then
      printf '%s\n' "$item"
    fi
  done
}

csv_add_tokens() {
  local base="$1"
  shift
  {
    csv_to_lines "$base"
    while [ "$#" -gt 0 ]; do
      printf '%s\n' "$1"
      shift
    done
  } | awk '!seen[$0]++' | paste -sd, -
}

csv_remove_tokens() {
  local base="$1"
  shift
  local remove_csv

  remove_csv=$(IFS=,; printf '%s' "$*")
  csv_to_lines "$base" | awk -v remove="$remove_csv" '
    BEGIN {
      n = split(remove, arr, ",")
      for (i = 1; i <= n; i++) {
        if (arr[i] != "") {
          drop[arr[i]] = 1
        }
      }
    }
    !drop[$0] && !seen[$0]++ { print }
  ' | paste -sd, -
}

contains_csv_token() {
  local csv="$1"
  local token="$2"
  local item

  IFS=',' read -r -a items <<<"$csv"
  for item in "${items[@]}"; do
    item="$(trim "$item")"
    if [ "$item" = "$token" ]; then
      return 0
    fi
  done
  return 1
}

join_by_comma() {
  local first=1
  local item
  for item in "$@"; do
    if [ "$first" -eq 1 ]; then
      printf '%s' "$item"
      first=0
    else
      printf ',%s' "$item"
    fi
  done
}

append_unique_server() {
  local target="$1"
  local existing

  for existing in "${MANAGED_SERVERS[@]}"; do
    if [ "$existing" = "$target" ]; then
      return 0
    fi
  done
  MANAGED_SERVERS+=("$target")
}

append_unique_selected() {
  local target="$1"
  local existing

  for existing in "${SELECTED_SERVERS[@]}"; do
    if [ "$existing" = "$target" ]; then
      return 0
    fi
  done
  SELECTED_SERVERS+=("$target")
}

is_managed_server() {
  local target="$1"
  local existing

  for existing in "${MANAGED_SERVERS[@]}"; do
    if [ "$existing" = "$target" ]; then
      return 0
    fi
  done
  return 1
}

discover_managed_servers() {
  local script_path header token

  MANAGED_SERVERS=()
  for script_path in "${MCP_SETUP_SCRIPTS[@]}"; do
    if [ ! -f "$script_path" ]; then
      continue
    fi

    header="$(sed -n 's/^# MCP:[[:space:]]*//p' "$script_path" | head -n 1 || true)"
    if [ -z "$header" ]; then
      continue
    fi

    header="${header//,/ }"
    for token in $header; do
      token="$(trim "$token")"
      if [ -n "$token" ]; then
        append_unique_server "$token"
      fi
    done
  done

  if [ "${#MANAGED_SERVERS[@]}" -eq 0 ]; then
    MANAGED_SERVERS=(asana notion)
  fi
}

build_default_target_servers() {
  local server

  DEFAULT_TARGET_SERVERS=()
  for server in "${MANAGED_SERVERS[@]}"; do
    if contains_csv_token "$DEFAULT_TARGET_EXCLUDE_RAW" "$server"; then
      continue
    fi
    DEFAULT_TARGET_SERVERS+=("$server")
  done

  if [ "${#DEFAULT_TARGET_SERVERS[@]}" -eq 0 ]; then
    DEFAULT_TARGET_SERVERS=("${MANAGED_SERVERS[@]}")
  fi
}

resolve_selected_servers() {
  local mode="$1"
  shift
  local token

  SELECTED_SERVERS=()

  if [ "$#" -eq 0 ]; then
    case "$mode" in
      status)
        SELECTED_SERVERS=("${MANAGED_SERVERS[@]}")
        ;;
      on|off|login)
        SELECTED_SERVERS=("${DEFAULT_TARGET_SERVERS[@]}")
        ;;
      *)
        SELECTED_SERVERS=("${MANAGED_SERVERS[@]}")
        ;;
    esac
  elif [ "${1:-}" = "--all" ]; then
    if [ "$#" -ne 1 ]; then
      echo "[error] --all cannot be combined with explicit server names" >&2
      return 1
    fi
    SELECTED_SERVERS=("${MANAGED_SERVERS[@]}")
  else
    for token in "$@"; do
      token="$(trim "$token")"
      if [ -z "$token" ]; then
        continue
      fi
      if ! is_managed_server "$token"; then
        echo "[error] unknown MCP server: $token" >&2
        echo "[hint] managed servers: $(join_by_comma "${MANAGED_SERVERS[@]}")" >&2
        return 1
      fi
      append_unique_selected "$token"
    done
  fi

  if [ "${#SELECTED_SERVERS[@]}" -eq 0 ]; then
    echo "[error] no target MCP servers selected" >&2
    return 1
  fi
}

print_server_catalog() {
  echo "managed_servers: $(join_by_comma "${MANAGED_SERVERS[@]}")"
  echo "default_targets: $(join_by_comma "${DEFAULT_TARGET_SERVERS[@]}")"
}

run_make_mcp() {
  local force_enabled="$1"
  local force_disabled="$2"

  mkdir -p "$PROJECT_CLAUDE_CONFIG_DIR" "$PROJECT_CODEX_HOME" "$PROJECT_GEMINI_CLI_HOME"
  write_project_env_file

  (
    cd "$NIX_HOME_REPO_ROOT"
    env \
      CLAUDE_CONFIG_DIR="$PROJECT_CLAUDE_CONFIG_DIR" \
      CODEX_HOME="$PROJECT_CODEX_HOME" \
      GEMINI_CLI_HOME="$PROJECT_GEMINI_CLI_HOME" \
      CLAUDE_MEM_MCP_SERVER="$GLOBAL_CLAUDE_MEM_MCP_SERVER" \
      NIX_HOME_MCP_DEFAULT_ENABLED=0 \
      NIX_HOME_MCP_FORCE_ENABLED="$force_enabled" \
      NIX_HOME_MCP_FORCE_DISABLED="$force_disabled" \
      make mcp
  )
}

run_with_project_env() {
  env \
    CLAUDE_CONFIG_DIR="$PROJECT_CLAUDE_CONFIG_DIR" \
    CODEX_HOME="$PROJECT_CODEX_HOME" \
    GEMINI_CLI_HOME="$PROJECT_GEMINI_CLI_HOME" \
    CLAUDE_MEM_MCP_SERVER="$GLOBAL_CLAUDE_MEM_MCP_SERVER" \
    "$@"
}

write_project_env_file() {
  mkdir -p "$(dirname "$PROJECT_ENV_FILE")"
  cat > "$PROJECT_ENV_FILE" <<EOF
# Generated by ok-mcp-toggle
export CLAUDE_CONFIG_DIR="$PROJECT_CLAUDE_CONFIG_DIR"
export CODEX_HOME="$PROJECT_CODEX_HOME"
export GEMINI_CLI_HOME="$PROJECT_GEMINI_CLI_HOME"
export CLAUDE_MEM_MCP_SERVER="$GLOBAL_CLAUDE_MEM_MCP_SERVER"
EOF
}

print_paths() {
  echo "project_root: $PROJECT_ROOT"
  echo "claude_config_dir: $PROJECT_CLAUDE_CONFIG_DIR"
  echo "codex_home: $PROJECT_CODEX_HOME"
  echo "gemini_cli_home: $PROJECT_GEMINI_CLI_HOME"
  echo "env_file: $PROJECT_ENV_FILE"
  echo "managed_servers: $(join_by_comma "${MANAGED_SERVERS[@]}")"
  echo "default_targets: $(join_by_comma "${DEFAULT_TARGET_SERVERS[@]}")"
}

print_status() {
  local gemini_enablement="$PROJECT_GEMINI_CLI_HOME/.gemini/mcp-server-enablement.json"
  local server

  print_paths
  echo
  echo "== codex =="
  if command -v codex >/dev/null 2>&1; then
    for server in "${SELECTED_SERVERS[@]}"; do
      local output enabled
      output="$(run_with_project_env codex mcp get "$server" --json 2>/dev/null || true)"
      if [ -z "$output" ]; then
        echo "$server: missing"
        continue
      fi

      if command -v jq >/dev/null 2>&1; then
        enabled="$(printf '%s' "$output" | jq -r 'if has("enabled") then (.enabled | tostring) else "unknown" end' 2>/dev/null || true)"
        [ -n "$enabled" ] || enabled="unknown"
      else
        enabled="configured"
      fi
      echo "$server: enabled=$enabled"
    done
  else
    echo "codex command not found"
  fi

  echo
  echo "== claude =="
  if command -v claude >/dev/null 2>&1; then
    for server in "${SELECTED_SERVERS[@]}"; do
      if run_with_project_env claude mcp get "$server" >/dev/null 2>&1; then
        echo "$server: present"
      else
        echo "$server: absent"
      fi
    done
  else
    echo "claude command not found"
  fi

  echo
  echo "== gemini =="
  if [ -f "$gemini_enablement" ] && command -v jq >/dev/null 2>&1; then
    for server in "${SELECTED_SERVERS[@]}"; do
      echo "$server: enabled=$(jq -r --arg name "$server" '
        if has($name) then
          if (.[$name] | type) == "object" and (.[$name] | has("enabled")) then
            (.[$name].enabled | tostring)
          else
            "unknown"
          end
        else
          "true"
        end
      ' "$gemini_enablement")"
    done
  else
    echo "enablement file or jq not found: $gemini_enablement"
  fi
}

run_login() {
  local server

  write_project_env_file

  if ! command -v codex >/dev/null 2>&1; then
    echo "[warn] codex command not found; skip OAuth login"
    return 0
  fi

  for server in "${SELECTED_SERVERS[@]}"; do
    echo "== codex mcp login $server =="
    if ! run_with_project_env codex mcp login "$server"; then
      echo "[warn] $server: codex mcp login failed or not applicable"
    fi
  done
}

MODE="${1:-}"

if [ -z "$MODE" ]; then
  usage
  exit 1
fi
shift

discover_managed_servers
build_default_target_servers

CURRENT_FORCE_ENABLED="${NIX_HOME_MCP_FORCE_ENABLED:-jina,claude-mem}"
CURRENT_FORCE_DISABLED="${NIX_HOME_MCP_FORCE_DISABLED:-}"

case "$MODE" in
  on)
    resolve_selected_servers "on" "$@"
    NEW_FORCE_ENABLED="$(csv_add_tokens "$CURRENT_FORCE_ENABLED" "${SELECTED_SERVERS[@]}")"
    NEW_FORCE_DISABLED="$(csv_remove_tokens "$CURRENT_FORCE_DISABLED" "${SELECTED_SERVERS[@]}")"
    run_make_mcp "$NEW_FORCE_ENABLED" "$NEW_FORCE_DISABLED"
    echo
    echo "[done] enabled: $(join_by_comma "${SELECTED_SERVERS[@]}")"
    echo "[next] start AI CLI from project shell: source \"$PROJECT_ENV_FILE\""
    ;;
  off)
    resolve_selected_servers "off" "$@"
    NEW_FORCE_ENABLED="$(csv_remove_tokens "$CURRENT_FORCE_ENABLED" "${SELECTED_SERVERS[@]}")"
    run_make_mcp "$NEW_FORCE_ENABLED" "$CURRENT_FORCE_DISABLED"
    echo
    echo "[done] removed from force-enabled: $(join_by_comma "${SELECTED_SERVERS[@]}")"
    echo "[next] start AI CLI from project shell: source \"$PROJECT_ENV_FILE\""
    ;;
  status)
    resolve_selected_servers "status" "$@"
    print_status
    ;;
  login)
    resolve_selected_servers "login" "$@"
    run_login
    ;;
  servers)
    print_server_catalog
    ;;
  paths)
    write_project_env_file
    print_paths
    ;;
  *)
    usage
    exit 1
    ;;
esac
