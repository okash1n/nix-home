#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ui_check.sh doctor
  ui_check.sh choose [--mode <mode>] [--tool <auto|playwright-cli|agent-browser>]
  ui_check.sh run --url <url> [options]

Options for choose/run:
  --mode <mode>        smoke|explore|auth|form|regression|network|trace|capture (default: smoke)
  --tool <tool>        auto|playwright-cli|agent-browser (default: auto)

Options for run:
  --url <url>          Target URL (required)
  --session <id>       Session ID (default: detected from agent conversation)
  --agent-name <name>  Codex|Claude|Gemini (default: auto-detect)
  --state-file <path>  Save auth/session state file
  --no-close           Keep browser session open

Examples:
  ui_check.sh doctor
  ui_check.sh choose --mode regression
  ui_check.sh run --mode explore --url https://example.com --agent-name Codex
  ui_check.sh run --mode auth --url https://example.com/login --session auth-01
EOF
}

fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

log() {
  echo "[info] $*"
}

sanitize_segment() {
  local raw="${1:-}"
  raw="$(printf '%s' "$raw" | tr -cs 'A-Za-z0-9._-' '-')"
  raw="${raw#-}"
  raw="${raw%-}"
  if [[ -z "$raw" ]]; then
    raw="session"
  fi
  printf '%s\n' "$raw"
}

jst_date() {
  TZ=Asia/Tokyo /bin/date +%Y%m%d
}

jst_minute_stamp() {
  TZ=Asia/Tokyo /bin/date +%Y%m%d%H%M
}

build_screenshot_path() {
  local artifact_dir="$1"
  local tool_name="$2"
  printf '%s/%s-%s.png\n' "$artifact_dir" "$(jst_minute_stamp)" "$tool_name"
}

playwright_session_id() {
  local raw="$1"
  local hash
  hash="$(printf '%s' "$raw" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')"
  printf 'pw%s\n' "${hash:0:8}"
}

normalize_mode() {
  local raw="${1:-smoke}"
  raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    smoke|explore|auth|form|regression|network|trace|capture)
      printf '%s\n' "$raw"
      ;;
    *)
      fail "Unknown mode: $raw"
      ;;
  esac
}

normalize_tool() {
  local raw="${1:-auto}"
  raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    auto)
      printf 'auto\n'
      ;;
    playwright|playwright-cli)
      printf 'playwright-cli\n'
      ;;
    agent|agent-browser)
      printf 'agent-browser\n'
      ;;
    *)
      fail "Unknown tool: $raw"
      ;;
  esac
}

normalize_agent_name() {
  local raw="${1:-}"
  raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    codex)
      printf 'Codex\n'
      ;;
    claude)
      printf 'Claude\n'
      ;;
    gemini)
      printf 'Gemini\n'
      ;;
    *)
      fail "Unknown agent name: ${1:-}"
      ;;
  esac
}

detect_agent_name() {
  if [[ -n "${OK_UI_CHECK_AGENT_NAME:-}" ]]; then
    normalize_agent_name "$OK_UI_CHECK_AGENT_NAME"
    return 0
  fi
  if [[ "${CODEX_SHELL:-0}" == "1" || -n "${CODEX_THREAD_ID:-}" || -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]]; then
    printf 'Codex\n'
    return 0
  fi
  if [[ "${CLAUDE_CODE:-0}" == "1" || -n "${CLAUDE_CODE_SESSION_ID:-}" || -n "${CLAUDECODE:-}" ]]; then
    printf 'Claude\n'
    return 0
  fi
  if [[ "${GEMINI_CLI:-0}" == "1" || -n "${GEMINI_SESSION_ID:-}" || -n "${GEMINI_AGENT:-}" ]]; then
    printf 'Gemini\n'
    return 0
  fi
  fail "Could not detect agent name. Use --agent-name Codex|Claude|Gemini"
}

detect_session_id() {
  if [[ -n "${OK_UI_CHECK_SESSION_ID:-}" ]]; then
    printf '%s\n' "$OK_UI_CHECK_SESSION_ID"
    return 0
  fi

  local candidate
  for candidate in \
    "${CODEX_THREAD_ID:-}" \
    "${CLAUDE_CODE_SESSION_ID:-}" \
    "${CLAUDE_SESSION_ID:-}" \
    "${GEMINI_SESSION_ID:-}" \
    "${GEMINI_CHAT_ID:-}" \
    "${GEMINI_AGENT_SESSION_ID:-}"
  do
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf 'default-session\n'
}

prepare_artifact_dir() {
  local agent_name="$1"
  local session_id="$2"
  local root="${OK_UI_CHECK_OUTPUT_ROOT:-$HOME/ui-check}"
  local dir="$root/$(jst_date)-${agent_name}-${session_id}"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

ensure_parent_dir() {
  local path="$1"
  local parent
  parent="$(dirname "$path")"
  mkdir -p "$parent"
}

pick_tool_for_mode() {
  local mode="$1"
  case "$mode" in
    smoke|explore|auth|form)
      printf 'agent-browser\n'
      ;;
    regression|network|trace|capture)
      printf 'playwright-cli\n'
      ;;
    *)
      fail "Unsupported mode for tool selection: $mode"
      ;;
  esac
}

reason_for_mode() {
  local mode="$1"
  case "$mode" in
    smoke|explore)
      printf '探索的チェック向け。snapshot -i で要素参照を見ながら素早く確認できるため。\n'
      ;;
    auth|form)
      printf 'フォーム/認証導線向け。要素参照を使って逐次確認しやすいため。\n'
      ;;
    regression)
      printf '回帰チェック向け。操作記録を再現しやすく、スナップショット運用しやすいため。\n'
      ;;
    network)
      printf 'ネットワーク観測向け。console/network 系コマンドを併用しやすいため。\n'
      ;;
    trace|capture)
      printf '記録重視の確認向け。trace/snapshot/capture 系を組み合わせやすいため。\n'
      ;;
    *)
      printf 'mode に応じた既定選択です。\n'
      ;;
  esac
}

resolve_tool() {
  local mode="$1"
  local requested="$2"

  if [[ "$requested" == "auto" ]]; then
    pick_tool_for_mode "$mode"
    return 0
  fi
  printf '%s\n' "$requested"
}

RUNNER=()

set_runner() {
  local cmd="$1"
  RUNNER=()

  case "$cmd" in
    playwright-cli)
      if command -v playwright-cli >/dev/null 2>&1; then
        RUNNER=(playwright-cli)
        return 0
      fi
      if command -v npx >/dev/null 2>&1; then
        RUNNER=(npx -y @playwright/cli)
        return 0
      fi
      ;;
    agent-browser)
      if command -v agent-browser >/dev/null 2>&1; then
        RUNNER=(agent-browser)
        return 0
      fi
      if command -v npx >/dev/null 2>&1; then
        RUNNER=(npx -y agent-browser)
        return 0
      fi
      ;;
  esac

  fail "Command not found: $cmd (and npx fallback is unavailable)"
}

run_cli() {
  echo "+ $*"
  CI=1 PLAYWRIGHT_HEADLESS=1 "$@"
}

capture_cli() {
  local outfile="$1"
  shift
  ensure_parent_dir "$outfile"
  echo "+ $* | tee $outfile"
  CI=1 PLAYWRIGHT_HEADLESS=1 "$@" 2>&1 | tee "$outfile"
}

cmd_doctor() {
  if command -v playwright-cli >/dev/null 2>&1; then
    echo "[ok] playwright-cli -> $(command -v playwright-cli)"
  else
    echo "[warn] playwright-cli is not available globally (npx fallback: @playwright/cli)"
  fi

  if command -v agent-browser >/dev/null 2>&1; then
    echo "[ok] agent-browser -> $(command -v agent-browser)"
  else
    echo "[warn] agent-browser is not available globally (npx fallback: agent-browser)"
  fi

  if command -v npx >/dev/null 2>&1; then
    echo "[ok] npx -> $(command -v npx)"
  else
    echo "[warn] npx is not available"
  fi

  echo "[info] artifact root: ${OK_UI_CHECK_OUTPUT_ROOT:-$HOME/ui-check}"
  echo "[info] JST date: $(jst_date)"
  echo "[info] detected session id: $(sanitize_segment "$(detect_session_id)")"
  echo "[info] policy: headless only (no browser UI)"
}

cmd_choose() {
  local mode="smoke"
  local tool="auto"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        mode="${2:-}"
        shift 2
        ;;
      --tool)
        tool="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown argument for choose: $1"
        ;;
    esac
  done

  mode="$(normalize_mode "$mode")"
  tool="$(normalize_tool "$tool")"
  local selected
  selected="$(resolve_tool "$mode" "$tool")"

  echo "mode=$mode"
  echo "tool=$selected"
  echo "reason=$(reason_for_mode "$mode")"
}

run_playwright_cli() {
  local mode="$1"
  local url="$2"
  local session="$3"
  local state_file="$4"
  local no_close="$5"
  local artifact_dir="$6"

  set_runner "playwright-cli"
  local session_args=()
  if [[ -n "$session" ]]; then
    local pw_session
    pw_session="$(playwright_session_id "$session")"
    session_args+=("-s=$pw_session")
    log "playwright_session=$pw_session (from $session)"
  fi

  log "tool=playwright-cli mode=$mode"
  run_cli "${RUNNER[@]}" "${session_args[@]}" open "$url"

  if [[ "$mode" == "trace" ]]; then
    run_cli "${RUNNER[@]}" "${session_args[@]}" tracing-start
  fi

  if ! run_cli "${RUNNER[@]}" "${session_args[@]}" snapshot "--filename=$artifact_dir/snapshot.yaml"; then
    capture_cli "$artifact_dir/snapshot.txt" "${RUNNER[@]}" "${session_args[@]}" snapshot
  fi

  local screenshot_path
  screenshot_path="$(build_screenshot_path "$artifact_dir" "playwright")"
  if ! run_cli "${RUNNER[@]}" "${session_args[@]}" screenshot "--filename=$screenshot_path"; then
    fail "Failed to write screenshot to fixed path: $screenshot_path"
  fi

  case "$mode" in
    regression|network|trace)
      capture_cli "$artifact_dir/console.log" "${RUNNER[@]}" "${session_args[@]}" console || true
      capture_cli "$artifact_dir/network.log" "${RUNNER[@]}" "${session_args[@]}" network || true
      ;;
  esac

  if [[ -n "$state_file" ]]; then
    ensure_parent_dir "$state_file"
    run_cli "${RUNNER[@]}" "${session_args[@]}" state-save "$state_file"
  fi

  if [[ "$mode" == "trace" ]]; then
    run_cli "${RUNNER[@]}" "${session_args[@]}" tracing-stop || true
  fi

  if [[ "$no_close" -eq 0 ]]; then
    run_cli "${RUNNER[@]}" "${session_args[@]}" close || true
  fi
}

run_agent_browser() {
  local mode="$1"
  local url="$2"
  local session="$3"
  local state_file="$4"
  local no_close="$5"
  local artifact_dir="$6"

  set_runner "agent-browser"
  local global_args=(--session "$session")
  if [[ -n "$session" ]]; then
    :
  fi

  log "tool=agent-browser mode=$mode"
  if ! run_cli "${RUNNER[@]}" "${global_args[@]}" open "$url"; then
    log "agent-browser open failed. trying session cleanup and one retry."
    run_cli "${RUNNER[@]}" "${global_args[@]}" close || true
    rm -f "$HOME/.agent-browser/${session}.sock" 2>/dev/null || true
    run_cli "${RUNNER[@]}" "${global_args[@]}" open "$url"
  fi
  run_cli "${RUNNER[@]}" "${global_args[@]}" wait --load networkidle || true
  capture_cli "$artifact_dir/snapshot.txt" "${RUNNER[@]}" "${global_args[@]}" snapshot -i
  local screenshot_path
  screenshot_path="$(build_screenshot_path "$artifact_dir" "agent-browser")"
  run_cli "${RUNNER[@]}" "${global_args[@]}" screenshot "$screenshot_path"

  if [[ -n "$state_file" ]]; then
    ensure_parent_dir "$state_file"
    run_cli "${RUNNER[@]}" "${global_args[@]}" state save "$state_file"
  fi

  if [[ "$no_close" -eq 0 ]]; then
    run_cli "${RUNNER[@]}" "${global_args[@]}" close || true
  fi
}

cmd_run() {
  local mode="smoke"
  local tool="auto"
  local url=""
  local session=""
  local agent_name=""
  local state_file=""
  local no_close=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        mode="${2:-}"
        shift 2
        ;;
      --tool)
        tool="${2:-}"
        shift 2
        ;;
      --url)
        url="${2:-}"
        shift 2
        ;;
      --session)
        session="${2:-}"
        shift 2
        ;;
      --agent-name)
        agent_name="${2:-}"
        shift 2
        ;;
      --state-file)
        state_file="${2:-}"
        shift 2
        ;;
      --no-close)
        no_close=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown argument for run: $1"
        ;;
    esac
  done

  mode="$(normalize_mode "$mode")"
  tool="$(normalize_tool "$tool")"
  [[ -n "$url" ]] || fail "--url is required"

  local normalized_agent
  if [[ -n "$agent_name" ]]; then
    normalized_agent="$(normalize_agent_name "$agent_name")"
  else
    normalized_agent="$(detect_agent_name)"
  fi

  local session_id
  if [[ -n "$session" ]]; then
    session_id="$(sanitize_segment "$session")"
  else
    session_id="$(sanitize_segment "$(detect_session_id)")"
  fi

  local artifact_dir
  artifact_dir="$(prepare_artifact_dir "$normalized_agent" "$session_id")"
  log "artifact_dir=$artifact_dir"
  log "agent_name=$normalized_agent"
  log "session_id=$session_id"

  if [[ -z "$state_file" && ( "$mode" == "auth" || "$mode" == "form" ) ]]; then
    state_file="$artifact_dir/state.json"
  fi

  local selected
  selected="$(resolve_tool "$mode" "$tool")"
  log "selected_tool=$selected"
  log "headless_policy=enabled (no browser UI)"

  case "$selected" in
    playwright-cli)
      run_playwright_cli "$mode" "$url" "$session_id" "$state_file" "$no_close" "$artifact_dir"
      ;;
    agent-browser)
      run_agent_browser "$mode" "$url" "$session_id" "$state_file" "$no_close" "$artifact_dir"
      ;;
    *)
      fail "Unsupported selected tool: $selected"
      ;;
  esac
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local sub="$1"
  shift

  case "$sub" in
    doctor)
      cmd_doctor "$@"
      ;;
    choose)
      cmd_choose "$@"
      ;;
    run)
      cmd_run "$@"
      ;;
    -h|--help)
      usage
      ;;
    *)
      fail "Unknown subcommand: $sub"
      ;;
  esac
}

main "$@"
