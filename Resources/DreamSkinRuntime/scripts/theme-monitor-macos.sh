#!/bin/bash

set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

MONITOR_LOCK="$STATE_ROOT/.theme-persistence-monitor.lock"

log_monitor() {
  ensure_state_root >/dev/null 2>&1 || true
  /usr/bin/printf '%s %s\n' "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "$THEME_PERSISTENCE_LOG" 2>/dev/null || true
}

config_value() {
  /usr/bin/plutil -extract "$1" raw -o - "$THEME_PERSISTENCE_PATH" 2>/dev/null || true
}

cleanup_monitor() {
  /bin/rm -f "$MONITOR_LOCK/pid" 2>/dev/null || true
  /bin/rmdir "$MONITOR_LOCK" 2>/dev/null || true
}

ensure_state_root
if ! /bin/mkdir "$MONITOR_LOCK" 2>/dev/null; then
  OWNER_PID="$(/bin/cat "$MONITOR_LOCK/pid" 2>/dev/null || true)"
  case "$OWNER_PID" in ''|*[!0-9]*) OWNER_PID="" ;; esac
  if [ -n "$OWNER_PID" ] && /bin/kill -0 "$OWNER_PID" 2>/dev/null; then
    log_monitor "A persistence monitor is already active; exiting duplicate."
    exit 0
  fi
  /bin/rm -f "$MONITOR_LOCK/pid" 2>/dev/null || true
  /bin/rmdir "$MONITOR_LOCK" 2>/dev/null || true
  /bin/mkdir "$MONITOR_LOCK" 2>/dev/null || { log_monitor "Could not reclaim a stale monitor lock."; exit 1; }
fi
/usr/bin/printf '%s\n' "$$" > "$MONITOR_LOCK/pid"
trap cleanup_monitor EXIT INT TERM

discover_codex_app || { log_monitor "Could not locate the signed Codex application."; exit 1; }
LAST_ATTEMPT_PID=""
LAST_ATTEMPT_AT=0

log_monitor "Persistence monitor started with engine $SKIN_VERSION."
while :; do
  ENABLED="$(config_value enabled)"
  [ "$ENABLED" = "true" ] || { log_monitor "Persistence disabled; monitor exiting."; exit 0; }

  if ! codex_is_running; then
    LAST_ATTEMPT_PID=""
    LAST_ATTEMPT_AT=0
    /bin/sleep 2
    continue
  fi

  PORT="$(config_value port)"
  case "$PORT" in ''|*[!0-9]*) PORT=9341 ;; esac
  if verified_cdp_endpoint "$PORT" && theme_runtime_state_ready; then
    /bin/sleep 2
    continue
  fi

  CODEX_PID="$(codex_main_pids | /usr/bin/head -n 1)"
  [ -n "$CODEX_PID" ] || { /bin/sleep 2; continue; }

  OPERATION="$(/usr/bin/plutil -extract status raw -o - "$OPERATION_STATE_PATH" 2>/dev/null || true)"
  case "$OPERATION" in applying|pausing) /bin/sleep 2; continue ;; esac
  [ -f "$THEME_DIR/theme.json" ] || { log_monitor "No staged theme exists; leaving Codex unchanged."; /bin/sleep 5; continue; }

  /bin/sleep 3
  codex_is_running || continue
  verified_cdp_endpoint "$PORT" && theme_runtime_state_ready && continue
  CURRENT_PID="$(codex_main_pids | /usr/bin/head -n 1)"
  [ "$CURRENT_PID" = "$CODEX_PID" ] || continue

  NOW="$(/bin/date +%s)"
  if [ "$CODEX_PID" = "$LAST_ATTEMPT_PID" ] && [ $((NOW - LAST_ATTEMPT_AT)) -lt 10 ]; then
    /bin/sleep 2
    continue
  fi
  LAST_ATTEMPT_AT="$NOW"
  LAST_ATTEMPT_PID="$CODEX_PID"
  log_monitor "Detected an unthemed Codex launch (pid $CODEX_PID); restoring the saved theme."
  if "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" --restart-existing >> "$THEME_PERSISTENCE_LOG" 2>&1; then
    log_monitor "Saved theme restored successfully."
  else
    log_monitor "Saved theme restoration failed; a later Codex launch will retry."
  fi
  /bin/sleep 2
done
