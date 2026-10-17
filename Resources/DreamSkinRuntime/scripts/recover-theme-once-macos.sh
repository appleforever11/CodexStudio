#!/bin/bash
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"
. "$SCRIPT_DIR/theme-switch-lock-macos.sh"
ensure_state_root
acquire_theme_switch_lock "$(new_operation_token)"
trap release_theme_switch_lock EXIT
[ "$(/usr/bin/plutil -extract enabled raw -o - "$THEME_PERSISTENCE_PATH" 2>/dev/null)" = true ] || exit 0
discover_codex_app
codex_is_running || exit 0
operation="$(/usr/bin/plutil -extract status raw -o - "$OPERATION_STATE_PATH" 2>/dev/null || true)"
case "$operation" in applying|pausing|failed) exit 0 ;; esac
[ -f "$THEME_DIR/theme.json" ] || exit 0
PORT="$(/usr/bin/plutil -extract port raw -o - "$THEME_PERSISTENCE_PATH" 2>/dev/null || true)"
case "$PORT" in ''|*[!0-9]*) PORT=9341 ;; esac
if verified_cdp_endpoint "$PORT" && theme_runtime_state_ready; then exit 0; fi
# Reconnect without restarting whenever the verified endpoint is still alive.
if verified_cdp_endpoint "$PORT"; then
  "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" >> "$THEME_PERSISTENCE_LOG" 2>&1
else
  # Give a normal launch time to expose its endpoint before deciding that it
  # needs a restart. Never reopen Codex if the user quits during this grace.
  for attempt in 1 2 3 4; do
    /bin/sleep 0.5
    codex_is_running || exit 0
    if verified_cdp_endpoint "$PORT"; then
      "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" >> "$THEME_PERSISTENCE_LOG" 2>&1
      exit 0
    fi
  done
  codex_is_running || exit 0
  "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" --restart-existing >> "$THEME_PERSISTENCE_LOG" 2>&1
fi
