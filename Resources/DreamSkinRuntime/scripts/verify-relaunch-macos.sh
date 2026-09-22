#!/bin/bash

# Safe CDP-only relaunch diagnostic. It never starts the injector, applies a
# theme, enables persistence, or writes active theme state.

set -Eeuo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

PORT=9343
PORT_EXPLICIT="false"
CODEX_STOPPED_BY_TEST="false"
CODEX_LAUNCHED_WITH_CDP="false"
TEST_FINISHED="false"
RECOVERY_SUCCEEDED="false"

activate_codex_window() {
  /usr/bin/open -a "$CODEX_BUNDLE" >/dev/null 2>&1 || true
}

recover_normal_chatgpt() {
  local recovery_ok="true"
  set +e
  release_codex_launchd_job
  if codex_is_running; then
    stop_codex true >/dev/null 2>&1 || recovery_ok="false"
  fi
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

record_test_exit() {
  local code="$1"
  [ "$TEST_FINISHED" = "true" ] && return 0
  [ "$code" -eq 0 ] && return 0
  [ "$CODEX_STOPPED_BY_TEST" = "true" ] || [ "$CODEX_LAUNCHED_WITH_CDP" = "true" ] || return 0
  recover_normal_chatgpt || true
  if [ "$RECOVERY_SUCCEEDED" = "true" ]; then
    printf 'CDP-only relaunch test failed, but normal ChatGPT recovery succeeded.\n' >&2
  else
    printf 'CDP-only relaunch test failed and normal ChatGPT recovery also failed.\n' >&2
  fi
}
trap 'code=$?; record_test_exit "$code"; exit "$code"' EXIT

while [ "$#" -gt 0 ]; do
  case "$1" in
    --port) PORT="${2:-}"; PORT_EXPLICIT="true"; shift 2 ;;
    *) fail "Unknown relaunch verification argument: $1" ;;
  esac
done
case "$PORT" in ''|*[!0-9]*) fail "Invalid port: $PORT" ;; esac
[ "$PORT" -ge 1024 ] && [ "$PORT" -le 65535 ] || fail "Port must be between 1024 and 65535."

discover_codex_app
require_macos_runtime
ensure_state_root
port_is_available "$PORT" || fail "Port $PORT is already in use; choose a free diagnostic port."

if codex_is_running; then
  CODEX_STOPPED_BY_TEST="true"
  stop_codex true
fi

release_codex_launchd_job
CODEX_LAUNCHED_WITH_CDP="true"
launch_codex_with_cdp "$PORT"
wait_for_cdp "$PORT" \
  || fail "ChatGPT did not expose a verified CDP endpoint on port $PORT within 45 seconds."

VERSION_JSON="$(/usr/bin/curl --noproxy '*' --silent --fail --max-time 2 \
  "http://127.0.0.1:${PORT}/json/version")" \
  || fail "The verified CDP endpoint stopped responding on port $PORT."
printf '%s\n' "$VERSION_JSON" | "$NODE" -e '
const value = JSON.parse(require("fs").readFileSync(0, "utf8"));
if (typeof value.webSocketDebuggerUrl !== "string" || !value.webSocketDebuggerUrl) {
  throw new Error("The CDP response did not include a WebSocket debugger URL.");
}
' || fail "The CDP response was missing a valid WebSocket debugger URL."
printf 'CDP verified on port %s. No injector or theme was started.\n' "$PORT"

stop_codex true
CODEX_LAUNCHED_WITH_CDP="false"
launch_codex_normally
wait_for_codex_running 20 \
  || fail "Normal ChatGPT did not relaunch after the CDP-only test."
activate_codex_window
TEST_FINISHED="true"
printf 'Normal ChatGPT relaunch verified; the CDP-only test passed.\n'
