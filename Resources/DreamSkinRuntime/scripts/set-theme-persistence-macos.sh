#!/bin/bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

ENABLED=""
PORT=9341
THEME_ID=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --enabled) ENABLED="${2:-}"; shift 2 ;;
    --port) PORT="${2:-}"; shift 2 ;;
    --theme-id) THEME_ID="${2:-}"; shift 2 ;;
    *) fail "Unknown persistence argument: $1" ;;
  esac
done
[ "$ENABLED" = "true" ] || [ "$ENABLED" = "false" ] || fail "Persistence enabled value must be true or false."
case "$PORT" in ''|*[!0-9]*) fail "Invalid persistence port: $PORT" ;; esac
[ "$PORT" -ge 1024 ] && [ "$PORT" -le 65535 ] || fail "Persistence port must be between 1024 and 65535."
case "$THEME_ID" in ''|*[!A-Za-z0-9_-]*) [ -z "$THEME_ID" ] || fail "Invalid persistence theme id." ;; esac
[ "${#THEME_ID}" -le 80 ] || fail "Persistence theme id is too long."

ensure_state_root
/bin/mkdir -p "$HOME/Library/LaunchAgents"
/bin/chmod 700 "$HOME/Library/LaunchAgents" 2>/dev/null || true

CONFIG_TEMP="$STATE_ROOT/.theme-persistence.$$"
AGENT_TEMP="$HOME/Library/LaunchAgents/.${THEME_PERSISTENCE_JOB_LABEL}.$$"
cleanup_persistence_stage() {
  /bin/rm -f "$CONFIG_TEMP" "$AGENT_TEMP"
}
trap cleanup_persistence_stage EXIT

/usr/bin/plutil -create xml1 "$CONFIG_TEMP"
/usr/bin/plutil -insert schemaVersion -integer 1 "$CONFIG_TEMP"
/usr/bin/plutil -insert enabled -bool "$ENABLED" "$CONFIG_TEMP"
/usr/bin/plutil -insert port -integer "$PORT" "$CONFIG_TEMP"
/usr/bin/plutil -insert themeId -string "$THEME_ID" "$CONFIG_TEMP"
/usr/bin/plutil -insert engineVersion -string "$SKIN_VERSION" "$CONFIG_TEMP"
/usr/bin/plutil -insert updatedAt -string "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')" "$CONFIG_TEMP"
/bin/chmod 600 "$CONFIG_TEMP"
/bin/mv -f "$CONFIG_TEMP" "$THEME_PERSISTENCE_PATH"

USER_DOMAIN="gui/$(/usr/bin/id -u)"
/bin/launchctl bootout "$USER_DOMAIN/$THEME_PERSISTENCE_JOB_LABEL" >/dev/null 2>&1 || true

if [ "$ENABLED" = "true" ]; then
  [ "$PROJECT_ROOT" = "$INSTALL_ROOT" ] || fail "Install the managed theme runtime before enabling persistence."
  [ -x "$SCRIPT_DIR/theme-monitor-macos.sh" ] || fail "The persistence monitor is missing or not executable."
  [ -f "$THEME_DIR/theme.json" ] || fail "Apply a theme before enabling persistence."

  /usr/bin/plutil -create xml1 "$AGENT_TEMP"
  /usr/bin/plutil -insert Label -string "$THEME_PERSISTENCE_JOB_LABEL" "$AGENT_TEMP"
  /usr/bin/plutil -insert ProgramArguments -xml "<array><string>$SCRIPT_DIR/theme-monitor-macos.sh</string></array>" "$AGENT_TEMP"
  /usr/bin/plutil -insert RunAtLoad -bool true "$AGENT_TEMP"
  /usr/bin/plutil -insert KeepAlive -bool true "$AGENT_TEMP"
  /usr/bin/plutil -insert ProcessType -string Background "$AGENT_TEMP"
  /usr/bin/plutil -insert StandardOutPath -string "$THEME_PERSISTENCE_LOG" "$AGENT_TEMP"
  /usr/bin/plutil -insert StandardErrorPath -string "$THEME_PERSISTENCE_LOG" "$AGENT_TEMP"
  /bin/chmod 600 "$AGENT_TEMP"
  /usr/bin/plutil -lint "$AGENT_TEMP" >/dev/null
  /bin/mv -f "$AGENT_TEMP" "$THEME_PERSISTENCE_AGENT"
  /bin/launchctl bootstrap "$USER_DOMAIN" "$THEME_PERSISTENCE_AGENT"
  /bin/launchctl enable "$USER_DOMAIN/$THEME_PERSISTENCE_JOB_LABEL" >/dev/null 2>&1 || true
  /bin/launchctl kickstart -k "$USER_DOMAIN/$THEME_PERSISTENCE_JOB_LABEL" >/dev/null 2>&1 || true
else
  if [ -f "$THEME_PERSISTENCE_AGENT" ] && [ ! -L "$THEME_PERSISTENCE_AGENT" ]; then
    CURRENT_LABEL="$(/usr/bin/plutil -extract Label raw -o - "$THEME_PERSISTENCE_AGENT" 2>/dev/null || true)"
    [ "$CURRENT_LABEL" != "$THEME_PERSISTENCE_JOB_LABEL" ] || /bin/rm -f "$THEME_PERSISTENCE_AGENT"
  fi
fi

/usr/bin/printf 'enabled=%s port=%s theme=%s engine=%s\n' "$ENABLED" "$PORT" "$THEME_ID" "$SKIN_VERSION"
