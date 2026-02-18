#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
TARGET_SERVERS=(asana notion)

usage() {
  cat <<'EOF'
Usage:
  mcp_asana_notion.sh on
  mcp_asana_notion.sh off
  mcp_asana_notion.sh status
  mcp_asana_notion.sh login
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

run_make_mcp() {
  local force_enabled="$1"
  local force_disabled="$2"

  (
    cd "$REPO_ROOT"
    env \
      NIX_HOME_MCP_DEFAULT_ENABLED=0 \
      NIX_HOME_MCP_FORCE_ENABLED="$force_enabled" \
      NIX_HOME_MCP_FORCE_DISABLED="$force_disabled" \
      make mcp
  )
}

print_status() {
  local gemini_home="${GEMINI_CLI_HOME:-$HOME/.config/gemini}"
  local gemini_enablement="$gemini_home/.gemini/mcp-server-enablement.json"
  local server

  echo "== codex =="
  if command -v codex >/dev/null 2>&1; then
    for server in "${TARGET_SERVERS[@]}"; do
      local output enabled
      output="$(codex mcp get "$server" --json 2>/dev/null || true)"
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
    for server in "${TARGET_SERVERS[@]}"; do
      if claude mcp get "$server" >/dev/null 2>&1; then
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
    for server in "${TARGET_SERVERS[@]}"; do
      echo "$server: enabled=$(jq -r --arg name "$server" 'if (.[$name] | type) == "object" and (.[$name] | has("enabled")) then (.[$name].enabled | tostring) else "unknown" end' "$gemini_enablement")"
    done
  else
    echo "enablement file or jq not found: $gemini_enablement"
  fi
}

run_login() {
  local server

  if ! command -v codex >/dev/null 2>&1; then
    echo "[warn] codex command not found; skip OAuth login"
    return 0
  fi

  for server in "${TARGET_SERVERS[@]}"; do
    echo "== codex mcp login $server =="
    codex mcp login "$server"
  done
}

MODE="${1:-}"

if [ -z "$MODE" ]; then
  usage
  exit 1
fi

CURRENT_FORCE_ENABLED="${NIX_HOME_MCP_FORCE_ENABLED:-jina,claude-mem}"
CURRENT_FORCE_DISABLED="${NIX_HOME_MCP_FORCE_DISABLED:-}"

case "$MODE" in
  on)
    NEW_FORCE_ENABLED="$(csv_add_tokens "$CURRENT_FORCE_ENABLED" asana notion)"
    NEW_FORCE_DISABLED="$(csv_remove_tokens "$CURRENT_FORCE_DISABLED" asana notion)"
    run_make_mcp "$NEW_FORCE_ENABLED" "$NEW_FORCE_DISABLED"
    echo
    echo "[done] asana/notion enabled (session-local policy applied)"
    echo "[next] restart target AI CLI session to load updated MCP list"
    ;;
  off)
    NEW_FORCE_ENABLED="$(csv_remove_tokens "$CURRENT_FORCE_ENABLED" asana notion)"
    run_make_mcp "$NEW_FORCE_ENABLED" "$CURRENT_FORCE_DISABLED"
    echo
    echo "[done] asana/notion removed from force-enabled list"
    echo "[next] restart target AI CLI session to load updated MCP list"
    ;;
  status)
    print_status
    ;;
  login)
    run_login
    ;;
  *)
    usage
    exit 1
    ;;
esac
