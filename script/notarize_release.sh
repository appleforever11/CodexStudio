#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-${CODEX_STUDIO_VERSION:-0.1.0}}"
ARCHIVE_PATH="${2:-$ROOT_DIR/dist/CodexStudio-${VERSION}-arm64.zip}"
DMG_PATH="${3:-$ROOT_DIR/dist/CodexStudio-${VERSION}-arm64.dmg}"
RELEASE_STAGE="${CODEX_STUDIO_RELEASE_STAGE:-$(mktemp -d /tmp/codexstudio-notary.XXXXXX)}"
APP_BUNDLE="${CODEX_STUDIO_APP_BUNDLE:-$RELEASE_STAGE/CodexStudio.app}"
NOTARY_PROFILE="${CODEX_STUDIO_NOTARY_PROFILE:-}"
NOTARY_KEY_PATH="${APPLE_NOTARY_KEY_PATH:-}"
NOTARY_KEY_ID="${APPLE_NOTARY_KEY_ID:-}"
NOTARY_ISSUER="${APPLE_NOTARY_ISSUER:-}"

if [[ -z "$NOTARY_PROFILE" && ( -z "$NOTARY_KEY_PATH" || -z "$NOTARY_KEY_ID" || -z "$NOTARY_ISSUER" ) ]]; then
  echo "No Apple notary credentials are configured." >&2
  echo "Set CODEX_STUDIO_NOTARY_PROFILE for a keychain profile, or provide APPLE_NOTARY_KEY_PATH, APPLE_NOTARY_KEY_ID, and APPLE_NOTARY_ISSUER." >&2
  echo "For secure local setup, run: xcrun notarytool store-credentials CodexStudio" >&2
  exit 2
fi

submit_and_require_acceptance() {
  local archive="$1"
  local label="$2"
  local result_file
  result_file="$(mktemp /tmp/codexstudio-notary-result.XXXXXX)"

  if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$archive" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait \
      --output-format json > "$result_file"
  else
    xcrun notarytool submit "$archive" \
      --key "$NOTARY_KEY_PATH" \
      --key-id "$NOTARY_KEY_ID" \
      --issuer "$NOTARY_ISSUER" \
      --wait \
      --output-format json > "$result_file"
  fi

  local status
  status="$(plutil -extract status raw -o - "$result_file")"
  if [[ "$status" != "Accepted" ]]; then
    echo "Apple notarization did not accept $archive (status: $status)." >&2
    rm -f "$result_file"
    exit 1
  fi

  echo "Notarization accepted: $label"
  rm -f "$result_file"
}

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Notary app bundle was not found: $APP_BUNDLE" >&2
  exit 1
fi
if [[ ! -f "$ARCHIVE_PATH" || ! -f "$DMG_PATH" ]]; then
  echo "Notary archives were not found: $ARCHIVE_PATH and $DMG_PATH" >&2
  exit 1
fi

submit_and_require_acceptance "$ARCHIVE_PATH" zip
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

rm -f "$ARCHIVE_PATH"
ditto --norsrc --noextattr --noqtn -c -k --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

CODEX_STUDIO_SKIP_BUILD=1 \
CODEX_STUDIO_APP_BUNDLE="$APP_BUNDLE" \
CODEX_STUDIO_VERSION="$VERSION" \
  "$ROOT_DIR/script/package_dmg.sh" "$DMG_PATH"

submit_and_require_acceptance "$DMG_PATH" dmg
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
echo "NOTARIZED_APP=$APP_BUNDLE"
echo "NOTARIZED_ARCHIVE=$ARCHIVE_PATH"
echo "NOTARIZED_DMG=$DMG_PATH"
