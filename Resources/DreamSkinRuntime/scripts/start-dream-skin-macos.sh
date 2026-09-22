#!/bin/bash

set -Eeuo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"
OPERATION_TOKEN=""
OPERATION_FINISHED="false"
VERIFY_OUTPUT=""
CODEX_STOPPED_BY_START="false"
CODEX_LAUNCHED_WITH_CDP="false"
INJECTOR_PID=""
INJECTOR_STARTED_AT=""
CLIENT_OPERATION_STARTED="false"
RECOVERY_ATTEMPTED="false"
RECOVERY_REQUIRED="false"
RECOVERY_SUCCEEDED="false"

activate_codex_window() {
  /usr/bin/open -a "$CODEX_BUNDLE" >/dev/null 2>&1 || true
}

disable_persistence_after_failure() {
  local persistence_script="$SCRIPT_DIR/set-theme-persistence-macos.sh"
  [ -x "$persistence_script" ] || return 0
  "$persistence_script" --enabled false --port "${PORT:-9341}" --theme-id "" \
    >/dev/null 2>&1
}

restore_base_appearance_after_failure() {
  [ "$CODEX_STOPPED_BY_START" = "true" ] || [ "$CODEX_LAUNCHED_WITH_CDP" = "true" ] || return 0
  codex_is_running && return 1
  [ -f "$THEME_BACKUP_PATH" ] || return 0
  "$NODE" "$SCRIPT_DIR/theme-config.mjs" restore "$CONFIG_PATH" "$THEME_BACKUP_PATH" \
    >/dev/null 2>&1
}

stop_owned_injector_after_failure() {
  [ -n "$INJECTOR_PID" ] || return 0
  [ -n "$INJECTOR_STARTED_AT" ] || return 0
  stop_owned_injector "$INJECTOR_PID" "$INJECTOR_STARTED_AT" "${PORT:-9341}"
}

recover_after_failed_start() {
  local recovery_ok="true"
  if [ "$CODEX_STOPPED_BY_START" != "true" ] && [ "$CODEX_LAUNCHED_WITH_CDP" != "true" ]; then
    return 0
  fi
  RECOVERY_REQUIRED="true"
  RECOVERY_ATTEMPTED="true"
  # This function runs from the EXIT trap. Keep the original failure status
  # intact while making every recovery step best effort and observable.
  set +e
  release_codex_launchd_job
  stop_owned_injector_after_failure || recovery_ok="false"

  # The operation owns the restart once either stop_codex or the CDP launch
  # was entered. Close any partial themed session before restoring config.
  if [ "$CODEX_STOPPED_BY_START" = "true" ] || [ "$CODEX_LAUNCHED_WITH_CDP" = "true" ]; then
    if codex_is_running; then
      stop_codex true >/dev/null 2>&1 || recovery_ok="false"
    fi
  fi

  restore_base_appearance_after_failure || recovery_ok="false"
  disable_persistence_after_failure || recovery_ok="false"
  mark_state_stale >/dev/null 2>&1 || true
  release_codex_launchd_job

  if ! codex_is_running; then
    launch_codex_normally >/dev/null 2>&1 || recovery_ok="false"
    wait_for_codex_running 20 >/dev/null 2>&1 || recovery_ok="false"
  fi
  if codex_is_running; then
    activate_codex_window
  else
    recovery_ok="false"
  fi
  set -e
  if [ "$recovery_ok" = "true" ]; then
    RECOVERY_SUCCEEDED="true"
    return 0
  fi
  return 1
}

record_start_exit() {
  local code="$1"
  local line="$2"
  local current_session=""
  [ -z "${VERIFY_OUTPUT:-}" ] || /bin/rm -f "$VERIFY_OUTPUT"
  [ "$code" -ne 0 ] || return 0
  [ "$OPERATION_FINISHED" != "true" ] || return 0
  ensure_state_root 2>/dev/null || true
  printf '%s exit=%s line=%s\n' "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')" "$code" "$line" \
    >> "$START_ERROR_LOG" 2>/dev/null || true
  recover_after_failed_start || true
  if [ -f "$STATE_PATH" ] && [ -n "${NODE:-}" ]; then
    current_session="$(state_field session 2>/dev/null || true)"
    [ "$current_session" != "applying" ] || mark_state_stale 2>/dev/null || true
  fi
  if [ -n "${OPERATION_TOKEN:-}" ]; then
    write_operation_state failed "$(dreamskin_text apply_unconfirmed)" "$OPERATION_TOKEN" 2>/dev/null || true
    if [ "$CLIENT_OPERATION_STARTED" = "true" ]; then
      finish_client_operation "${PORT:-9341}" error "$(dreamskin_text apply_unconfirmed)" \
        "$OPERATION_TOKEN" 1500 >/dev/null 2>&1 || true
    fi
  fi
  if [ "$RECOVERY_REQUIRED" != "true" ]; then
    printf 'ChatGPT Dream Skin: start failed at line %s (exit %s). See %s\n' \
      "$line" "$code" "$START_ERROR_LOG" >&2
  elif [ "$RECOVERY_SUCCEEDED" = "true" ]; then
    notify_user "$(dreamskin_text apply_failed_recovered)"
    printf 'ChatGPT Dream Skin: start failed at line %s (exit %s); normal ChatGPT recovery succeeded. See %s\n' \
      "$line" "$code" "$START_ERROR_LOG" >&2
  else
    notify_user "$(dreamskin_text apply_failed_recovery_failed)"
    printf 'ChatGPT Dream Skin: start failed at line %s (exit %s); normal ChatGPT recovery failed. See %s\n' \
      "$line" "$code" "$START_ERROR_LOG" >&2
  fi
}
trap 'code=$?; record_start_exit "$code" "$LINENO"; exit "$code"' EXIT
# Convert termination signals into normal shell exits so the EXIT trap performs
# the same recovery path as any other failed apply.
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

PORT=9341
PORT_EXPLICIT="false"
RESTART_EXISTING="false"
PROMPT_RESTART="false"
FOREGROUND_INJECTOR="false"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --port) PORT="${2:-}"; PORT_EXPLICIT="true"; shift 2 ;;
    --restart-existing) RESTART_EXISTING="true"; shift ;;
    --prompt-restart) PROMPT_RESTART="true"; shift ;;
    --foreground-injector) FOREGROUND_INJECTOR="true"; shift ;;
    *) fail "Unknown start argument: $1" ;;
  esac
done
case "$PORT" in ''|*[!0-9]*) fail "Invalid port: $PORT" ;; esac
[ "$PORT" -ge 1024 ] && [ "$PORT" -le 65535 ] || fail "Port must be between 1024 and 65535."

ensure_state_root
if [ "$FOREGROUND_INJECTOR" != "true" ]; then
  OPERATION_TOKEN="$(new_operation_token)"
  write_operation_state applying "$(dreamskin_text applying_skin)" "$OPERATION_TOKEN" \
    || fail "Could not publish the apply operation state."
fi
discover_codex_app
require_signed_node_runtime

if [ "$PORT_EXPLICIT" = "false" ] && [ -f "$STATE_PATH" ]; then
  saved_port="$(state_field port)" || fail "Could not read the existing state port."
  [ -n "$saved_port" ] && PORT="$saved_port"
fi

DEBUG_READY="false"
if verified_cdp_endpoint "$PORT"; then DEBUG_READY="true"; fi

if [ "$DEBUG_READY" = "true" ] && [ -n "$OPERATION_TOKEN" ]; then
  if begin_client_operation "$PORT" apply 3000 "$OPERATION_TOKEN" >/dev/null 2>&1; then
    CLIENT_OPERATION_STARTED="true"
  fi
fi

# A connected renderer can show progress before the App check. Before this
# script launches or restarts ChatGPT, verify the complete bundle.
if [ "$DEBUG_READY" = "false" ]; then
  verify_macos_app_signature deep
else
  verify_macos_app_signature quick
fi

if codex_is_running && [ "$DEBUG_READY" = "false" ]; then
  if [ "$PROMPT_RESTART" = "true" ] && [ "$RESTART_EXISTING" = "false" ]; then
    if ! /usr/bin/osascript - "$(dreamskin_text restart_prompt)" \
      "$(dreamskin_text restart_and_apply)" "$(dreamskin_text cancel)" <<'APPLESCRIPT' >/dev/null
on run argv
  set promptText to item 1 of argv
  set okLabel to item 2 of argv
  set cancelLabel to item 3 of argv
  display dialog promptText buttons {cancelLabel, okLabel} default button okLabel cancel button cancelLabel with title "ChatGPT Dream Skin"
end run
APPLESCRIPT
    then
      write_operation_state cancelled "$(dreamskin_text cancelled_unchanged)" "$OPERATION_TOKEN" \
        || fail "Could not publish the cancelled apply state."
      finish_client_operation "$PORT" cancelled "$(dreamskin_text cancelled_unchanged)" \
        "$OPERATION_TOKEN" 1500 >/dev/null 2>&1 || true
      OPERATION_FINISHED="true"
      exit 0
    fi
    RESTART_EXISTING="true"
  fi
  [ "$RESTART_EXISTING" = "true" ] || fail "ChatGPT is already running without the verified skin CDP endpoint. Close it first or pass --restart-existing."
  CODEX_STOPPED_BY_START="true"
  stop_codex true
fi

if [ -f "$STATE_PATH" ]; then
  stop_recorded_injector_if_owned
fi

if [ "$DEBUG_READY" = "false" ]; then
  # Codex is closed on this path (never started, or stopped just above), so it
  # is safe to sync the appearanceTheme pin to the staged theme before launch.
  # Best-effort: a config we refuse to rewrite should not block starting.
  sync_appearance_pin >/dev/null \
    || printf 'Warning: could not sync Codex appearanceTheme to the active theme; native menus may keep the previous appearance.\n' >&2
  PORT="$(select_available_port "$PORT")"
  printf 'Launching ChatGPT with skin debug port %s…\n' "$PORT" >&2
  CODEX_LAUNCHED_WITH_CDP="true"
  launch_codex_with_cdp "$PORT"
  # Never start the injector until the signed ChatGPT main process owns the
  # requested listener and /json/version has responded successfully.
  if ! wait_for_cdp "$PORT"; then
    fail "ChatGPT did not expose a verified loopback CDP endpoint on port $PORT within 45 seconds. See $APP_LOG and $APP_ERROR_LOG"
  fi
  if [ "$FOREGROUND_INJECTOR" != "true" ]; then
    INJECTOR_PID="$(launch_injector_daemon "$PORT")"
    INJECTOR_STARTED_AT="$(process_started_at "$INJECTOR_PID")"
    [ -n "$INJECTOR_STARTED_AT" ] || fail "Could not record the injector process start time."
  fi
fi

# LaunchServices activation reaches the already-running, identity-bound App.
# Do not use -n here: a second instance can arrive before ChatGPT has registered
# its reopen handler and leave a debuggable renderer without a native window.
activate_codex_window

if [ "$FOREGROUND_INJECTOR" = "true" ]; then
  "$NODE" "$INJECTOR" --watch --port "$PORT" --theme-dir "$THEME_DIR" \
    --operation-state "$OPERATION_STATE_PATH" --operation-ack "$OPERATION_ACK_PATH"
  foreground_code=$?
  [ "$foreground_code" -eq 0 ] || fail "The foreground injector exited with status $foreground_code. See $INJECTOR_ERROR_LOG"
  OPERATION_FINISHED="true"
  exit 0
fi

if [ -z "$INJECTOR_PID" ]; then
  INJECTOR_PID="$(launch_injector_daemon "$PORT")"
fi
/bin/sleep 0.15
/bin/kill -0 "$INJECTOR_PID" 2>/dev/null || fail "The injector exited during startup. See $INJECTOR_ERROR_LOG"
CODEX_PID="$(codex_main_pids | /usr/bin/head -n 1)"
write_state "$PORT" "$INJECTOR_PID" "$INJECTOR_STARTED_AT" "$CODEX_PID"

# Commit active only after the renderer, exact theme, and payload revision verify.
VERIFY_OUTPUT="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/dream-skin-verify.XXXXXX")"
/bin/chmod 600 "$VERIFY_OUTPUT"
cleanup_verify_output() {
  [ -z "${VERIFY_OUTPUT:-}" ] || /bin/rm -f "$VERIFY_OUTPUT"
  VERIFY_OUTPUT=""
}
if "$NODE" "$INJECTOR" --verify --port "$PORT" --theme-dir "$THEME_DIR" --timeout-ms 20000 >"$VERIFY_OUTPUT" 2>/dev/null; then
  verify_code=0
else
  verify_code=$?
fi
if [ "$verify_code" -ne 0 ]; then
  # A slow App startup may register its reopen handler after CDP. Activate the
  # exact bundle once more before the final force-inject and verification pass.
  activate_codex_window
  if [ -n "$OPERATION_TOKEN" ]; then
    "$NODE" "$INJECTOR" --once --port "$PORT" --theme-dir "$THEME_DIR" --timeout-ms 15000 \
      --operation-token "$OPERATION_TOKEN" >/dev/null 2>&1 || true
  else
    "$NODE" "$INJECTOR" --once --port "$PORT" --theme-dir "$THEME_DIR" --timeout-ms 15000 >/dev/null 2>&1 || true
  fi
  if "$NODE" "$INJECTOR" --verify --port "$PORT" --theme-dir "$THEME_DIR" --timeout-ms 12000 >"$VERIFY_OUTPUT" 2>/dev/null; then
    verify_code=0
  else
    verify_code=$?
  fi
fi
if [ "$verify_code" -ne 0 ]; then
  # Verify the PID/path/start-time tuple before changing state. If the watcher
  # cannot be stopped safely, preserve the state as evidence and fail closed.
  if ! stop_recorded_injector; then
    cleanup_verify_output
    fail "Injection verification failed and the recorded injector could not be stopped safely; state was preserved. See $INJECTOR_ERROR_LOG"
  fi
  mark_state_stale || true
  cleanup_verify_output
  fail "Injection verification failed. The injector was stopped; see $INJECTOR_ERROR_LOG"
fi
cleanup_verify_output

mark_state_active || fail "Could not commit the verified active skin state."
write_operation_state success "$(dreamskin_text skin_applied)" "$OPERATION_TOKEN" \
  || fail "Could not publish the completed apply state."
OPERATION_FINISHED="true"
printf 'ChatGPT Dream Skin %s is active on loopback port %s.\n' "$SKIN_VERSION" "$PORT"
