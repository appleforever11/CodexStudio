# Injector lifecycle, signed runtime reuse, and hot reapply.

stop_recorded_injector() {
  [ -f "$STATE_PATH" ] || return 0
  local pid
  local saved_port
  local saved_start
  local saved_node
  local saved_injector
  if ! pid="$(state_field injectorPid 2>/dev/null)" || [ -z "${pid:-}" ]; then
    printf 'Dream Skin state is damaged or missing its injector PID; state was preserved.\n' >&2
    return 1
  fi
  # Already paused / no daemon
  if [ "$pid" = "0" ]; then
    /bin/launchctl remove "$INJECTOR_JOB_LABEL" >/dev/null 2>&1 || true
    return 0
  fi
  case "$pid" in
    *[!0-9]*|??????????*)
      printf 'Recorded Dream Skin injector PID is invalid; state was preserved.\n' >&2
      return 1
      ;;
  esac
  while [ "${pid#0}" != "$pid" ]; do pid="${pid#0}"; done
  if [ -z "$pid" ]; then
    /bin/launchctl remove "$INJECTOR_JOB_LABEL" >/dev/null 2>&1 || true
    return 0
  fi

  # Load and validate every recorded identity field before probing or
  # signalling the PID.  Missing fields are not treated as a harmless legacy
  # state: preserving the evidence is safer than guessing which process is
  # allowed to receive TERM/KILL.
  saved_port="$(state_field port 2>/dev/null || true)"
  saved_start="$(state_field injectorStartedAt 2>/dev/null || true)"
  saved_node="$(state_field nodePath 2>/dev/null || true)"
  saved_injector="$(state_field injectorPath 2>/dev/null || true)"
  case "$saved_port" in
    ''|*[!0-9]*)
      printf 'Recorded Dream Skin injector port is missing or invalid; state was preserved.\n' >&2
      return 1
      ;;
  esac
  [ "$saved_port" -ge 1024 ] && [ "$saved_port" -le 65535 ] || {
    printf 'Recorded Dream Skin injector port is out of range; state was preserved.\n' >&2
    return 1
  }
  if [ -z "$saved_start" ] || [ -z "$saved_node" ] || [ -z "$saved_injector" ]; then
    printf 'Recorded Dream Skin injector identity is incomplete; state was preserved.\n' >&2
    return 1
  fi
  /bin/kill -0 "$pid" 2>/dev/null || {
    /bin/launchctl remove "$INJECTOR_JOB_LABEL" >/dev/null 2>&1 || true
    return 0
  }
  if ! recorded_injector_process_matches "$pid" "$saved_start" "$saved_node" "$saved_injector" "$saved_port"; then
    # The process may have exited between the initial kill -0 probe and the
    # identity check. A dead (or already reaped) recorded PID is safe to
    # forget; a live PID with mismatched identity is never signalled.
    if ! /bin/kill -0 "$pid" 2>/dev/null || [ -z "$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)" ]; then
      /bin/launchctl remove "$INJECTOR_JOB_LABEL" >/dev/null 2>&1 || true
      return 0
    fi
    printf 'Recorded injector PID %s is live but its identity does not match; refusing to signal it.\n' "$pid" >&2
    return 1
  fi
  /bin/launchctl remove "$INJECTOR_JOB_LABEL" >/dev/null 2>&1 || true
  /bin/kill -TERM "$pid" 2>/dev/null || true
  local deadline=$((SECONDS + 6))
  while recorded_injector_process_matches "$pid" "$saved_start" "$saved_node" "$saved_injector" "$saved_port" \
    && [ "$SECONDS" -lt "$deadline" ]; do
    /bin/sleep 0.2
  done
  if recorded_injector_process_matches "$pid" "$saved_start" "$saved_node" "$saved_injector" "$saved_port"; then
    /bin/kill -KILL "$pid" 2>/dev/null || true
  fi
  deadline=$((SECONDS + 2))
  while recorded_injector_process_matches "$pid" "$saved_start" "$saved_node" "$saved_injector" "$saved_port" \
    && [ "$SECONDS" -lt "$deadline" ]; do
    /bin/sleep 0.1
  done
  if recorded_injector_process_matches "$pid" "$saved_start" "$saved_node" "$saved_injector" "$saved_port"; then
    printf 'Could not stop the recorded Dream Skin injector (PID %s).\n' "$pid" >&2
    return 1
  fi
  return 0
}

launch_injector_daemon() {
  local port="$1"
  local pid=""
  local deadline=$((SECONDS + 10))
  : > "$INJECTOR_LOG"
  : > "$INJECTOR_ERROR_LOG"
  /bin/launchctl remove "$INJECTOR_JOB_LABEL" >/dev/null 2>&1 || true

  # SwiftBar may terminate background children when a click action finishes.
  # A submitted user job owns the watcher independently of that action.
  if /bin/launchctl submit -l "$INJECTOR_JOB_LABEL" -o "$INJECTOR_LOG" -e "$INJECTOR_ERROR_LOG" -- \
    "$NODE" "$INJECTOR" --watch --port "$port" --theme-dir "$THEME_DIR" \
    --operation-state "$OPERATION_STATE_PATH" --operation-ack "$OPERATION_ACK_PATH" \
    >/dev/null 2>&1; then
    while [ "$SECONDS" -lt "$deadline" ]; do
      pid="$(/bin/launchctl print "gui/$(/usr/bin/id -u)/$INJECTOR_JOB_LABEL" 2>/dev/null \
        | /usr/bin/awk '/^[[:space:]]*pid = [0-9]+/{print $3; exit}')"
      if [ -n "$pid" ] && /bin/kill -0 "$pid" 2>/dev/null; then
        printf '%s\n' "$pid"
        return 0
      fi
      /bin/sleep 0.2
    done
    /bin/launchctl remove "$INJECTOR_JOB_LABEL" >/dev/null 2>&1 || true
  fi

  # Fallback for systems where launchctl submit is unavailable.
  /usr/bin/nohup "$NODE" "$INJECTOR" --watch --port "$port" --theme-dir "$THEME_DIR" \
    --operation-state "$OPERATION_STATE_PATH" --operation-ack "$OPERATION_ACK_PATH" \
    >>"$INJECTOR_LOG" 2>>"$INJECTOR_ERROR_LOG" &
  pid="$!"
  /bin/sleep 0.15
  if [ -n "$pid" ] && /bin/kill -0 "$pid" 2>/dev/null; then
    printf '%s\n' "$pid"
    return 0
  fi
  fail "The injector did not start. See $INJECTOR_ERROR_LOG and $INJECTOR_LOG"
}

# Resolve Node only through the discovered and signed official ChatGPT bundle.
ensure_node_runtime() {
  if [ "$DREAM_SKIN_VALIDATED_RUNTIME_PID" = "$$" ] \
    && [ -n "$DREAM_SKIN_VALIDATED_RUNTIME_NODE" ] \
    && [ "${NODE:-}" = "$DREAM_SKIN_VALIDATED_RUNTIME_NODE" ] \
    && [ "${CODEX_BUNDLE:-}" = "$DREAM_SKIN_VALIDATED_RUNTIME_BUNDLE" ] \
    && [ "${CODEX_EXE:-}" = "$DREAM_SKIN_VALIDATED_RUNTIME_EXE" ]; then
    return 0
  fi
  discover_codex_app
  require_signed_node_runtime
}

# Fast path when CDP is already open: restart injector + one-shot inject.
# Returns 0 on success, 1 if CDP is not ready (caller should full-start).
hot_reapply_theme() {
  local port="${1:-9341}"
  local timeout_ms="${2:-8000}"
  local operation_token="${3:-}"
  local operation_args=()
  local inj_pid=""
  local injector_protocol=""
  local injector_mode=""
  local started_at=""
  local codex_pid=""

  # A generic HTTP listener is not enough for a hot re-apply: only use the
  # endpoint already verified as belonging to the official Codex process.
  ensure_node_runtime || return 1
  verified_cdp_endpoint "$port" || return 1
  [ -n "$operation_token" ] || operation_token="$(new_operation_token)"
  write_operation_state applying "$(dreamskin_text applying_selected_theme)" "$operation_token" || return 1
  operation_args=(--operation-token "$operation_token")

  injector_protocol="$(state_field injectorProtocol 2>/dev/null || true)"
  injector_mode="$(state_field injectorMode 2>/dev/null || true)"
  if [ "$injector_protocol" = "2" ] || [ "$injector_protocol" = "3" ]; then
    inj_pid="$(/bin/ps -axo pid=,command= | /usr/bin/awk -v inj="$INJECTOR" -v port="$port" '
      index($0, inj) && index($0, "--watch") && index($0, "--port " port " --theme-dir ") { print $1; exit }
    ')"
  fi
  if ! "$NODE" "$INJECTOR" --once --port "$port" --theme-dir "$THEME_DIR" \
    --timeout-ms "$timeout_ms" "${operation_args[@]}" >/dev/null 2>&1; then
    return 1
  fi

  # A current watcher reloads theme files itself. Start one only when absent.
  if [ -n "$inj_pid" ] && /bin/kill -0 "$inj_pid" 2>/dev/null \
    && [ "$injector_mode" != "control" ]; then
    mark_state_active || return 1
    write_operation_state success "$(dreamskin_text skin_applied)" "$operation_token" || return 1
    return 0
  fi
  stop_recorded_injector 2>/dev/null || return 1
  inj_pid="$(launch_injector_daemon "$port")"
  /bin/kill -0 "$inj_pid" 2>/dev/null || return 1
  started_at="$(process_started_at "$inj_pid")"
  codex_pid="$(codex_main_pids 2>/dev/null | /usr/bin/head -n 1)"
  [ -n "$started_at" ] || started_at="$(/bin/date)"
  write_state "$port" "$inj_pid" "$started_at" "${codex_pid:-0}" active
  write_operation_state success "$(dreamskin_text skin_applied)" "$operation_token" || return 1
  return 0
}
