# Process identity, CDP, port, and runtime health helpers.

codex_main_pids() {
  local pid
  local command_line
  while read -r pid command_line; do
    [ -n "$pid" ] || continue
    case "$command_line" in
      "$CODEX_EXE"*) pid_is_codex_executable "$pid" && printf '%s\n' "$pid" ;;
    esac
  done < <(/bin/ps -axo pid=,command=)
}

codex_is_running() {
  [ -n "$(codex_main_pids)" ]
}

active_theme_appearance() {
  "$NODE" -e '
const fs = require("node:fs");
let appearance = "auto";
try { appearance = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).appearance; } catch {}
process.stdout.write(appearance === "light" || appearance === "dark" ? appearance : "auto");
' "$THEME_DIR/theme.json"
}

# Pin Codex appearanceTheme to the staged theme's declared appearance (or put
# the user's original line back for auto themes). Callers must only run this
# while Codex is closed; config writes race the app's own saves otherwise.
sync_appearance_pin() {
  "$NODE" "$SCRIPT_DIR/theme-config.mjs" install "$CONFIG_PATH" "$THEME_BACKUP_PATH" "$(active_theme_appearance)"
}

process_started_at() {
  /bin/ps -p "$1" -o lstart= 2>/dev/null | /usr/bin/awk '{$1=$1; print}'
}

recorded_injector_process_matches() {
  local pid="$1"
  local expected_start="${2:-}"
  local expected_node="${3:-}"
  local expected_injector="${4:-}"
  local expected_port="${5:-}"
  local command_line=""
  local command_lower=""
  local node_lower=""
  local injector_lower=""
  local actual_start=""

  # A recorded PID is only safe to signal when the complete launch identity
  # was persisted.  Do not fall back to the current process paths: a stale or
  # hand-edited state file must fail closed instead of authorizing a reused PID.
  [ -n "$expected_start" ] && [ -n "$expected_node" ] && [ -n "$expected_injector" ] || return 1
  case "$expected_port" in
    ''|*[!0-9]*) return 1 ;;
  esac
  /bin/kill -0 "$pid" 2>/dev/null || return 1
  command_line="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
  [ -n "$command_line" ] || return 1
  command_lower="$(printf '%s' "$command_line" | /usr/bin/tr '[:upper:]' '[:lower:]')"
  injector_lower="$(printf '%s' "$expected_injector" | /usr/bin/tr '[:upper:]' '[:lower:]')"
  node_lower="$(printf '%s' "$expected_node" | /usr/bin/tr '[:upper:]' '[:lower:]')"
  case "$command_lower" in "$node_lower "*) ;; *) return 1 ;; esac
  # The watcher launch shape is deliberately matched as tokens.  In
  # particular, `--port 93410` must never satisfy a saved `9341` identity.
  case "$command_lower" in
    *"$injector_lower --watch --port $expected_port --theme-dir "*) ;;
    *) return 1 ;;
  esac
  actual_start="$(process_started_at "$pid")"
  [ -n "$actual_start" ] && [ "$actual_start" = "$expected_start" ] || return 1
  return 0
}

stop_codex() {
  local allow_force="${1:-false}"
  local deadline
  local pid

  release_codex_launchd_job
  codex_is_running || return 0
  /usr/bin/osascript -e 'tell application id "com.openai.codex" to quit' >/dev/null 2>&1 || true
  deadline=$((SECONDS + 15))
  while codex_is_running && [ "$SECONDS" -lt "$deadline" ]; do /bin/sleep 0.25; done
  codex_is_running || return 0

  [ "$allow_force" = "true" ] || fail "ChatGPT did not close within 15 seconds; explicit restart authorization is required for a forced stop."
  while IFS= read -r pid; do
    [ -n "$pid" ] && /bin/kill -TERM "$pid" 2>/dev/null || true
  done < <(codex_main_pids)
  deadline=$((SECONDS + 5))
  while codex_is_running && [ "$SECONDS" -lt "$deadline" ]; do /bin/sleep 0.25; done
  if codex_is_running; then
    while IFS= read -r pid; do
      [ -n "$pid" ] && /bin/kill -KILL "$pid" 2>/dev/null || true
    done < <(codex_main_pids)
  fi
  /bin/sleep 0.5
  codex_is_running && fail "ChatGPT could not be stopped safely."
  return 0
}

listener_pids() {
  /usr/sbin/lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | /usr/bin/sort -u || true
}

port_is_available() {
  [ -z "$(listener_pids "$1")" ]
}

canonical_existing_path() {
  local input="$1"
  local directory
  local basename
  [ -e "$input" ] || return 1
  directory="$(cd "$(dirname "$input")" 2>/dev/null && pwd -P)" || return 1
  basename="$(basename "$input")"
  printf '%s/%s\n' "$directory" "$basename"
}

process_executable_path() {
  /usr/sbin/lsof -a -p "$1" -d txt -Fn 2>/dev/null \
    | /usr/bin/awk '/^n/{sub(/^n/, ""); print; exit}'
}

pid_is_codex_executable() {
  local actual
  local actual_canonical
  local expected_canonical
  actual="$(process_executable_path "$1")"
  actual_canonical="$(canonical_existing_path "$actual" 2>/dev/null || true)"
  expected_canonical="$(canonical_existing_path "$CODEX_EXE" 2>/dev/null || true)"
  [ -n "$actual_canonical" ] && [ "$actual_canonical" = "$expected_canonical" ]
}

pid_is_codex_descendant() {
  local current="$1"
  local command_line=""
  local parent=""
  local depth=0
  while [ "$current" -gt 1 ] 2>/dev/null && [ "$depth" -lt 32 ]; do
    command_line="$(/bin/ps -p "$current" -o command= 2>/dev/null || true)"
    case "$command_line" in
      "$CODEX_EXE"*) pid_is_codex_executable "$current" && return 0 ;;
    esac
    parent="$(/bin/ps -p "$current" -o ppid= 2>/dev/null | /usr/bin/awk '{$1=$1; print}')"
    case "$parent" in ''|*[!0-9]*) return 1 ;; esac
    [ "$parent" -ne "$current" ] || return 1
    current="$parent"
    depth=$((depth + 1))
  done
  return 1
}

port_belongs_to_codex() {
  local port="$1"
  local found="false"
  local pid
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    found="true"
    pid_is_codex_descendant "$pid" || return 1
  done < <(listener_pids "$port")
  [ "$found" = "true" ]
}

# Cheap: can we talk to a loopback DevTools HTTP endpoint?
cdp_http_ready() {
  local port="$1"
  /usr/bin/curl --noproxy '*' --silent --fail --max-time 1 \
    "http://127.0.0.1:${port}/json/version" >/dev/null 2>&1
}

verified_cdp_endpoint() {
  local port="$1"
  port_belongs_to_codex "$port" || return 1
  cdp_http_ready "$port"
}

# A loopback endpoint alone is not proof that the current Codex process is the
# themed one. The endpoint can survive an updater handoff while state.json
# still describes the previous process. Require the active theme, staged
# theme identity, and recorded Codex PID to agree before treating a launch as
# healthy.
theme_runtime_state_ready() {
  local session=""
  local active_id=""
  local expected_id=""
  local recorded_pid=""
  local current_pid=""
  [ -f "$STATE_PATH" ] || return 1
  [ -f "$THEME_DIR/theme.json" ] || return 1
  session="$(/usr/bin/plutil -extract session raw -o - "$STATE_PATH" 2>/dev/null || true)"
  active_id="$(/usr/bin/plutil -extract appliedThemeId raw -o - "$STATE_PATH" 2>/dev/null || true)"
  expected_id="$(/usr/bin/plutil -extract id raw -o - "$THEME_DIR/theme.json" 2>/dev/null || true)"
  recorded_pid="$(/usr/bin/plutil -extract codexPid raw -o - "$STATE_PATH" 2>/dev/null || true)"
  current_pid="$(codex_main_pids | /usr/bin/head -n 1)"
  [ "$session" = "active" ]
  [ -n "$active_id" ] && [ "$active_id" = "$expected_id" ]
  [ -n "$recorded_pid" ] && [ "$recorded_pid" != "0" ] && [ "$recorded_pid" = "$current_pid" ]
}

select_available_port() {
  local preferred="$1"
  local candidate="$preferred"
  local last=$((preferred + 100))
  [ "$last" -le 65535 ] || last=65535
  while [ "$candidate" -le "$last" ]; do
    if port_is_available "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
    candidate=$((candidate + 1))
  done
  fail "No free loopback port was found between $preferred and $last."
}

wait_for_cdp() {
  local port="$1"
  local deadline=$((SECONDS + 45))
  local last_note=0
  while [ "$SECONDS" -lt "$deadline" ]; do
    verified_cdp_endpoint "$port" && return 0
    if [ $((SECONDS - last_note)) -ge 8 ]; then
      last_note=$SECONDS
      printf 'Waiting for ChatGPT debug port %s… (%ss)\n' "$port" "$SECONDS" >&2
    fi
    /bin/sleep 0.35
  done
  return 1
}
