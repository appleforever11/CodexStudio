#!/bin/bash

set -euo pipefail

if [ -z "${HOME:-}" ]; then
  CURRENT_USER="$(/usr/bin/id -un)"
  HOME="$(/usr/bin/dscl . -read "/Users/$CURRENT_USER" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')"
  [ -n "$HOME" ] || { printf 'ChatGPT Dream Skin: could not resolve the current macOS home directory.\n' >&2; exit 1; }
  export HOME
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/localization-macos.sh"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# Keep this file as the stable sourced entrypoint used by every launcher.
# The modules share this shell's variables and intentionally load in dependency
# order; function bodies resolve later declarations at call time.
. "$SCRIPT_DIR/common/runtime-context-macos.sh"
. "$SCRIPT_DIR/common/operations-macos.sh"
. "$SCRIPT_DIR/common/presets-and-app-macos.sh"
. "$SCRIPT_DIR/common/process-macos.sh"
. "$SCRIPT_DIR/common/state-macos.sh"
. "$SCRIPT_DIR/common/injector-macos.sh"
. "$SCRIPT_DIR/common/codex-launch-macos.sh"
