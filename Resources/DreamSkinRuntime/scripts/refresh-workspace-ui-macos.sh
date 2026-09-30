#!/bin/bash
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"
discover_codex_app
ensure_state_root
hot_reapply_theme "$(state_field port)" 12000
