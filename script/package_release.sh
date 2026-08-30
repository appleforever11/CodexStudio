#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_CONFIGURATION="${CODEX_STUDIO_BUILD_CONFIGURATION:-release}"
RELEASE_SIGNING_IDENTITY="${CODEX_STUDIO_SIGNING_IDENTITY:-}"

if [[ $# -ge 1 ]]; then
  VERSION="$1"
else
  VERSION="${CODEX_STUDIO_VERSION:-0.1.0}"
fi

ARCHIVE_PATH="${2:-$DIST_DIR/CodexStudio-${VERSION}-arm64.zip}"
RELEASE_STAGE="${CODEX_STUDIO_RELEASE_STAGE:-$(mktemp -d /tmp/codexstudio-release.XXXXXX)}"
APP_BUNDLE="${CODEX_STUDIO_APP_BUNDLE:-$RELEASE_STAGE/CodexStudio.app}"

mkdir -p "$(dirname "$ARCHIVE_PATH")"

if [[ "${CODEX_STUDIO_SKIP_BUILD:-0}" != "1" ]]; then
  CODEX_STUDIO_DIST_DIR="$RELEASE_STAGE" \
  CODEX_STUDIO_BUILD_CONFIGURATION="$BUILD_CONFIGURATION" \
  CODEX_STUDIO_VERSION="$VERSION" \
  CODEX_STUDIO_SIGNING_IDENTITY="$RELEASE_SIGNING_IDENTITY" \
    "$ROOT_DIR/script/build_and_run.sh" build
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Release app bundle was not found: $APP_BUNDLE" >&2
  exit 1
fi

codesign --verify --deep --strict "$APP_BUNDLE"
rm -f "$ARCHIVE_PATH"
ditto --norsrc --noextattr --noqtn -c -k --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

echo "APP_BUNDLE=$APP_BUNDLE"
echo "ARCHIVE_PATH=$ARCHIVE_PATH"
