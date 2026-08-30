#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_CONFIGURATION="${CODEX_STUDIO_BUILD_CONFIGURATION:-release}"
RELEASE_SIGNING_IDENTITY="${CODEX_STUDIO_SIGNING_IDENTITY:-}"
VERSION="${CODEX_STUDIO_VERSION:-0.1.0}"
DMG_PATH="${1:-$DIST_DIR/CodexStudio-${VERSION}-arm64.dmg}"
RELEASE_STAGE="${CODEX_STUDIO_RELEASE_STAGE:-$(mktemp -d /tmp/codexstudio-dmg.XXXXXX)}"
APP_BUNDLE="${CODEX_STUDIO_APP_BUNDLE:-$RELEASE_STAGE/CodexStudio.app}"
STAGING_DIR="$(mktemp -d /tmp/codexstudio-dmg-staging.XXXXXX)"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

if [[ "${CODEX_STUDIO_SKIP_BUILD:-0}" != "1" && ! -d "$APP_BUNDLE" ]]; then
  CODEX_STUDIO_DIST_DIR="$RELEASE_STAGE" \
  CODEX_STUDIO_BUILD_CONFIGURATION="$BUILD_CONFIGURATION" \
  CODEX_STUDIO_VERSION="$VERSION" \
  CODEX_STUDIO_SIGNING_IDENTITY="$RELEASE_SIGNING_IDENTITY" \
    "$ROOT_DIR/script/build_and_run.sh" build
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "DMG app bundle was not found: $APP_BUNDLE" >&2
  exit 1
fi

codesign --verify --deep --strict "$APP_BUNDLE"
ditto --norsrc --noextattr --noqtn "$APP_BUNDLE" "$STAGING_DIR/CodexStudio.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
mkdir -p "$(dirname "$DMG_PATH")"
hdiutil create \
  -volname "Codex Studio" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

if [[ -z "$RELEASE_SIGNING_IDENTITY" ]]; then
  RELEASE_SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
fi

if [[ -n "$RELEASE_SIGNING_IDENTITY" && "$RELEASE_SIGNING_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$RELEASE_SIGNING_IDENTITY" "$DMG_PATH"
else
  echo "Warning: DMG was not Developer ID signed; set CODEX_STUDIO_SIGNING_IDENTITY for distribution." >&2
fi

hdiutil verify "$DMG_PATH"
echo "DMG_PATH=$DMG_PATH"
