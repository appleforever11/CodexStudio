#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT_DIR/Resources/CodexThemedLauncherTemplate/Contents/MacOS/CodexThemedLauncher"
COMMON="$ROOT_DIR/Resources/DreamSkinRuntime/scripts/common-macos.sh"
COMMON_MODULES="$ROOT_DIR/Resources/DreamSkinRuntime/scripts/common"
MONITOR="$ROOT_DIR/Resources/DreamSkinRuntime/scripts/theme-monitor-macos.sh"
BUILD_SCRIPT="$ROOT_DIR/script/build_and_run.sh"

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! /usr/bin/grep -Fq "$expected" "$file"; then
    echo "Launch recovery check failed: '$expected' is missing from $file." >&2
    exit 1
  fi
}

/bin/bash -n "$COMMON" "$COMMON_MODULES"/*.sh "$MONITOR"
/bin/bash -n "$BUILD_SCRIPT"
/bin/zsh -n "$LAUNCHER"

assert_contains "$LAUNCHER" "themed_runtime_ready"
assert_contains "$LAUNCHER" "wait_for_themed_runtime 20"
assert_contains "$LAUNCHER" "start_engine_with_retries"
assert_contains "$LAUNCHER" 'while [ "$attempt" -le 3 ]'
assert_contains "$COMMON" 'common/process-macos.sh'
assert_contains "$COMMON_MODULES/process-macos.sh" "theme_runtime_state_ready"
assert_contains "$COMMON_MODULES/process-macos.sh" 'recorded_pid="'
assert_contains "$MONITOR" 'verified_cdp_endpoint "$PORT" && theme_runtime_state_ready'
assert_contains "$MONITOR" "LAST_ATTEMPT_PID"
assert_contains "$BUILD_SCRIPT" "bundle_process_ids"
assert_contains "$BUILD_SCRIPT" "@loader_path/../Frameworks/Sparkle.framework/Versions/B/Sparkle"
if /usr/bin/grep -Fq "LAST_REPAIRED_PID" "$MONITOR"; then
  echo "Launch recovery check failed: stale LAST_REPAIRED_PID guard remains." >&2
  exit 1
fi

echo "Launch recovery guard checks passed."
