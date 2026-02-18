#!/usr/bin/env bash
# Register launchd agent for llm-agents auto update
set -euo pipefail

LABEL="${NIX_HOME_LLM_AGENTS_UPDATE_LABEL:-com.okash1n.nix-home.llm-agents-update}"
NIX_HOME_DIR="${NIX_HOME_DIR:-$HOME/nix-home}"
STATE_DIR="${NIX_HOME_STATE_DIR:-$HOME/.local/state/nix-home}"
AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$AGENTS_DIR/$LABEL.plist"
UPDATE_SCRIPT_PATH="$NIX_HOME_DIR/scripts/auto-update-llm-agents.sh"
LAUNCHD_LOG_PATH="$STATE_DIR/llm-agents-auto-update.launchd.log"

launchctl_bin="$(command -v launchctl 2>/dev/null || true)"
if [ -z "$launchctl_bin" ] && [ -x "/bin/launchctl" ]; then
  launchctl_bin="/bin/launchctl"
fi

if [ -z "$launchctl_bin" ]; then
  echo "[warn] launchctl command not found"
  exit 0
fi

if [ ! -x "$UPDATE_SCRIPT_PATH" ]; then
  echo "[warn] update script not found or not executable: $UPDATE_SCRIPT_PATH"
  exit 0
fi

mkdir -p "$AGENTS_DIR" "$STATE_DIR"

tmp_plist="$(mktemp)"
cat > "$tmp_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$UPDATE_SCRIPT_PATH</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$NIX_HOME_DIR</string>
  <key>RunAtLoad</key>
  <true/>
  <key>StartCalendarInterval</key>
  <array>
    <dict>
      <key>Hour</key>
      <integer>10</integer>
      <key>Minute</key>
      <integer>30</integer>
    </dict>
    <dict>
      <key>Hour</key>
      <integer>22</integer>
      <key>Minute</key>
      <integer>30</integer>
    </dict>
  </array>
  <key>StandardOutPath</key>
  <string>$LAUNCHD_LOG_PATH</string>
  <key>StandardErrorPath</key>
  <string>$LAUNCHD_LOG_PATH</string>
</dict>
</plist>
EOF

plist_changed=0
if [ ! -f "$PLIST_PATH" ] || ! cmp -s "$tmp_plist" "$PLIST_PATH"; then
  mv "$tmp_plist" "$PLIST_PATH"
  chmod 644 "$PLIST_PATH"
  plist_changed=1
  echo "[done] updated launch agent plist: $PLIST_PATH"
else
  rm -f "$tmp_plist"
  echo "[skip] launch agent plist is up to date: $PLIST_PATH"
fi

uid_value="$(id -u)"
gui_domain="gui/$uid_value"
user_domain="user/$uid_value"

is_loaded_in_domain() {
  local domain="$1"
  "$launchctl_bin" print "$domain/$LABEL" >/dev/null 2>&1
}

bootout_domain() {
  local domain="$1"
  "$launchctl_bin" bootout "$domain/$LABEL" >/dev/null 2>&1 || true
}

bootstrap_domain() {
  local domain="$1"
  "$launchctl_bin" bootstrap "$domain" "$PLIST_PATH" >/dev/null 2>&1
}

loaded_domain=""
if is_loaded_in_domain "$gui_domain"; then
  loaded_domain="$gui_domain"
elif is_loaded_in_domain "$user_domain"; then
  loaded_domain="$user_domain"
fi

if [ -n "$loaded_domain" ] && [ "$plist_changed" -eq 1 ]; then
  bootout_domain "$loaded_domain"
  loaded_domain=""
fi

if [ -z "$loaded_domain" ]; then
  if bootstrap_domain "$gui_domain"; then
    loaded_domain="$gui_domain"
  elif bootstrap_domain "$user_domain"; then
    loaded_domain="$user_domain"
  else
    echo "[warn] failed to bootstrap launch agent: $LABEL"
    exit 0
  fi
  echo "[done] launch agent loaded: $loaded_domain/$LABEL"
else
  echo "[skip] launch agent already loaded: $loaded_domain/$LABEL"
fi

"$launchctl_bin" enable "$loaded_domain/$LABEL" >/dev/null 2>&1 || true

