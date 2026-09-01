# Operation tokens and atomic operation-state coordination.

new_operation_token() {
  local timestamp_ms=""
  if [ -x /usr/bin/perl ]; then
    timestamp_ms="$(LC_ALL=C /usr/bin/perl -MTime::HiRes=time -e 'printf "%.0f", time() * 1000')"
  else
    timestamp_ms="$(/bin/date +%s)000"
  fi
  /usr/bin/printf '%s:%s:%s\n' "$$" "$timestamp_ms" "${RANDOM:-0}"
}

operation_token_is_valid() {
  LC_ALL=C /usr/bin/printf '%s' "$1" \
    | LC_ALL=C /usr/bin/grep -Eq '^[0-9]{1,12}:[0-9]{13}:[0-9]{1,8}$'
}

write_operation_state() {
  local status="$1"
  local message="${2:-}"
  local operation_token="${3:-}"
  local terminal_policy="${4:-match}"
  local token_guarded="false"
  local current_token=""
  local current_status=""
  local current_updated_at=""
  local current_age=0
  local current_ttl=0
  local temporary=""
  local updated_at=""
  local lock_path=""
  local lock_mtime=""
  local now=""
  local attempts=0
  local result=0
  case "$status" in
    applying|pausing|success|paused|cancelled|failed) ;;
    *) return 1 ;;
  esac
  case "$terminal_policy" in match|idle) ;; *) return 1 ;; esac
  case "$message" in *$'\n'*|*$'\r'*) return 1 ;; esac
  [ "${#message}" -le 240 ] || return 1
  if [ -n "$operation_token" ]; then
    token_guarded="true"
  else
    operation_token="$(new_operation_token)"
  fi
  operation_token_is_valid "$operation_token" || return 1
  ensure_state_root
  lock_path="$STATE_ROOT/.operation-state.lock"
  while ! /bin/mkdir "$lock_path" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 50 ]; then return 1; fi
    lock_mtime="$(/usr/bin/stat -f '%m' "$lock_path" 2>/dev/null || true)"
    now="$(/bin/date +%s)"
    case "$lock_mtime" in
      ''|*[!0-9]*) ;;
      *) [ $((now - lock_mtime)) -le 5 ] || /bin/rm -rf "$lock_path" ;;
    esac
    /bin/sleep 0.02
  done
  case "$status" in
    success|paused|cancelled|failed)
      if [ "$token_guarded" = "true" ] && [ -f "$OPERATION_STATE_PATH" ]; then
        current_token="$(/usr/bin/plutil -extract operationToken raw -o - "$OPERATION_STATE_PATH" 2>/dev/null || true)"
        if [ "$current_token" != "$operation_token" ]; then
          if [ "$terminal_policy" = "idle" ]; then
            current_status="$(/usr/bin/plutil -extract status raw -o - "$OPERATION_STATE_PATH" 2>/dev/null || true)"
            current_updated_at="$(/usr/bin/plutil -extract updatedAt raw -o - "$OPERATION_STATE_PATH" 2>/dev/null || true)"
            case "$current_updated_at" in ''|*[!0-9]*) current_updated_at=0 ;; esac
            now="$(/bin/date +%s)"
            current_age=$((now - current_updated_at))
            case "$current_status" in applying) current_ttl=180 ;; pausing) current_ttl=90 ;; *) current_ttl=0 ;; esac
            if [ "$current_ttl" -gt 0 ] && [ "$current_age" -ge -5 ] \
              && [ "$current_age" -le "$current_ttl" ]; then
              result=2
            fi
          elif operation_token_is_valid "$current_token"; then
            result=2
          fi
        fi
      fi
      ;;
  esac
  if [ "$result" -eq 0 ]; then
    temporary="$OPERATION_STATE_PATH.$$.tmp"
    updated_at="$(/bin/date +%s)"
    /bin/rm -f "$temporary"
    if ! /usr/bin/plutil -create xml1 "$temporary" >/dev/null 2>&1 \
      || ! /usr/bin/plutil -insert status -string "$status" "$temporary" >/dev/null 2>&1 \
      || ! /usr/bin/plutil -insert message -string "$message" "$temporary" >/dev/null 2>&1 \
      || ! /usr/bin/plutil -insert operationToken -string "$operation_token" "$temporary" >/dev/null 2>&1 \
      || ! /usr/bin/plutil -insert updatedAt -integer "$updated_at" "$temporary" >/dev/null 2>&1; then
      /bin/rm -f "$temporary"
      result=1
    else
      /bin/chmod 600 "$temporary"
      /bin/mv -f "$temporary" "$OPERATION_STATE_PATH" || result=1
    fi
  fi
  /bin/rm -rf "$lock_path"
  return "$result"
}

clear_operation_state() {
  /bin/rm -f "$OPERATION_STATE_PATH"
}

begin_client_operation() {
  local port="$1"
  local kind="$2"
  local timeout_ms="${3:-3000}"
  local token="${4:-}"
  case "$kind" in apply|pause|switch) ;; *) return 1 ;; esac
  [ -n "$token" ] || token="$(new_operation_token)"
  operation_token_is_valid "$token" || return 1
  token="$("$NODE" "$INJECTOR" --begin-operation --operation-kind "$kind" \
    --operation-token "$token" --port "$port" --timeout-ms "$timeout_ms" \
    2>>"$INJECTOR_ERROR_LOG")" || return 1
  operation_token_is_valid "$token" || return 1
  /usr/bin/printf '%s\n' "$token"
}

finish_client_operation() {
  local port="$1"
  local state="$2"
  local message="$3"
  local token="$4"
  local timeout_ms="${5:-1500}"
  case "$state" in success|error|cancelled) ;; *) return 1 ;; esac
  operation_token_is_valid "$token" || return 1
  [ -n "${NODE:-}" ] && [ -x "$NODE" ] || return 1
  "$NODE" "$INJECTOR" --finish-operation --operation-ui-state "$state" \
    --operation-message "$message" --operation-token "$token" \
    --port "$port" --timeout-ms "$timeout_ms" 2>>"$INJECTOR_ERROR_LOG"
}
