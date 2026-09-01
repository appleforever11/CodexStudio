# Shared runtime paths, diagnostics, and user-facing helpers.

INJECTOR="$SCRIPT_DIR/injector.mjs"
INSTALL_ROOT="$HOME/.codex/codex-dream-skin-studio"
STATE_ROOT="$HOME/Library/Application Support/CodexDreamSkinStudio"
STATE_PATH="$STATE_ROOT/state.json"
OPERATION_STATE_PATH="$STATE_ROOT/operation-state.plist"
OPERATION_ACK_PATH="$STATE_ROOT/operation-control-ack.json"
THEME_BACKUP_PATH="$STATE_ROOT/theme-backup.json"
THEME_DIR="$STATE_ROOT/theme"
CONFIG_PATH="$HOME/.codex/config.toml"
INJECTOR_LOG="$STATE_ROOT/injector.log"
INJECTOR_ERROR_LOG="$STATE_ROOT/injector-error.log"
APP_LOG="$STATE_ROOT/codex-launch.log"
APP_ERROR_LOG="$STATE_ROOT/codex-launch-error.log"
START_ERROR_LOG="$STATE_ROOT/start-error.log"
THEME_PERSISTENCE_PATH="$STATE_ROOT/theme-persistence.plist"
THEME_PERSISTENCE_LOG="$STATE_ROOT/theme-persistence.log"
THEME_PERSISTENCE_JOB_LABEL="com.codexthemes.theme-monitor"
THEME_PERSISTENCE_AGENT="$HOME/Library/LaunchAgents/$THEME_PERSISTENCE_JOB_LABEL.plist"
CODEX_APP_JOB_LABEL="com.openai.codex-dream-skin-studio.app"
INJECTOR_JOB_LABEL="com.openai.codex-dream-skin-studio.injector"
EXPECTED_CODEX_TEAM_ID="2DC432GLL2"
EXPECTED_CODEX_REQUIREMENT="anchor apple generic and certificate leaf[subject.OU] = \"$EXPECTED_CODEX_TEAM_ID\""
SKIN_VERSION="$(/usr/bin/tr -d '[:space:]' < "$PROJECT_ROOT/VERSION" 2>/dev/null || true)"
[ -n "$SKIN_VERSION" ] || SKIN_VERSION="1.9.1"
DREAM_SKIN_VALIDATED_RUNTIME_PID=""
DREAM_SKIN_VALIDATED_RUNTIME_BUNDLE=""
DREAM_SKIN_VALIDATED_RUNTIME_EXE=""
DREAM_SKIN_VALIDATED_RUNTIME_NODE=""

fail() {
  local message="$*"
  if [ -n "${START_ERROR_LOG:-}" ] && [ -n "${STATE_ROOT:-}" ]; then
    /bin/mkdir -p "$STATE_ROOT" 2>/dev/null || true
    printf '%s %s\n' "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')" "$message" >> "$START_ERROR_LOG" 2>/dev/null || true
  fi
  printf 'ChatGPT Dream Skin: %s\n' "$message" >&2
  exit 1
}

notify_user() {
  local message="$*"
  /usr/bin/osascript - "$message" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  display notification (item 1 of argv) with title "ChatGPT Dream Skin"
end run
APPLESCRIPT
}

alert_user() {
  local message="$*"
  /usr/bin/osascript - "$message" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  display alert "ChatGPT Dream Skin" message (item 1 of argv)
end run
APPLESCRIPT
}

ensure_state_root() {
  /bin/mkdir -p "$STATE_ROOT"
  /bin/chmod 700 "$STATE_ROOT"
}
