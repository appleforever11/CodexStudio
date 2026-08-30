#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CodexStudio"
BUNDLE_ID="local.kevinhowe.CodexStudio"
MIN_SYSTEM_VERSION="14.0"
BUILD_CONFIGURATION="${CODEX_STUDIO_BUILD_CONFIGURATION:-debug}"
APP_VERSION="${CODEX_STUDIO_VERSION:-0.1.0}"
if [[ -n "${CODEX_STUDIO_BUILD_NUMBER:-}" ]]; then
  BUILD_NUMBER="$CODEX_STUDIO_BUILD_NUMBER"
else
  IFS='.' read -r VERSION_MAJOR VERSION_MINOR VERSION_PATCH <<< "$APP_VERSION"
  BUILD_NUMBER="$((10#${VERSION_MAJOR:-0} * 1000000 + 10#${VERSION_MINOR:-0} * 1000 + 10#${VERSION_PATCH:-0}))"
fi
SIGNING_IDENTITY="${CODEX_STUDIO_SIGNING_IDENTITY:-}"
SPARKLE_FEED_URL="${CODEX_STUDIO_SPARKLE_FEED_URL:-https://github.com/appleforever11/CodexStudio/releases/latest/download/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${CODEX_STUDIO_SPARKLE_PUBLIC_ED_KEY:-1QwxGTbkRZRB2hZJ8wTAJwytcGxG1v5i9/l/oEVuPzg=}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${CODEX_STUDIO_DIST_DIR:-$ROOT_DIR/dist}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_FILE="$ROOT_DIR/Resources/CodexStudio.icns"
THEME_PACKS_DIR="$ROOT_DIR/Resources/ThemePacks"
DREAM_SKIN_RUNTIME_DIR="$ROOT_DIR/Resources/DreamSkinRuntime"
DOCKDOOR_LAUNCHER_DIR="$ROOT_DIR/Resources/CodexThemedLauncherTemplate"
FRAMEWORKS_DIR="$APP_CONTENTS/Frameworks"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  for identity_pattern in 'Developer ID Application' 'Apple Development'; do
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' -v pattern="$identity_pattern" '$0 ~ /^[[:space:]]*[0-9]+\)/ && index($2, pattern) {print $2; exit}')"
    [[ -n "$SIGNING_IDENTITY" ]] && break
  done
fi
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$ROOT_DIR"
swift build --product "$APP_NAME" --configuration "$BUILD_CONFIGURATION"
BUILD_BINARY="$(swift build --show-bin-path --configuration "$BUILD_CONFIGURATION")/$APP_NAME"

SPARKLE_FRAMEWORK="${SPARKLE_FRAMEWORK_PATH:-$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework}"
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build/artifacts/sparkle" -type d -path '*/Sparkle.framework' -print -quit 2>/dev/null || true)"
fi
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework was not found. Run swift package resolve first." >&2
  exit 1
fi

if [[ ! -d "$THEME_PACKS_DIR" ]]; then
  echo "Bundled theme packs were not found at $THEME_PACKS_DIR." >&2
  exit 1
fi
THEME_PACK_COUNT="$(find "$THEME_PACKS_DIR" -mindepth 1 -maxdepth 1 -type d -print | wc -l | tr -d '[:space:]')"
if [[ "$THEME_PACK_COUNT" -eq 0 ]]; then
  echo "No bundled theme packs were found at $THEME_PACKS_DIR." >&2
  exit 1
fi
if [[ ! -d "$DREAM_SKIN_RUNTIME_DIR/scripts" ]]; then
  echo "Bundled Codex theme runtime was not found at $DREAM_SKIN_RUNTIME_DIR." >&2
  exit 1
fi
if [[ ! -f "$DOCKDOOR_LAUNCHER_DIR/Contents/Info.plist" || ! -f "$DOCKDOOR_LAUNCHER_DIR/Contents/MacOS/CodexThemedLauncher" ]]; then
  echo "Bundled DockDoor launcher was not found at $DOCKDOOR_LAUNCHER_DIR." >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$FRAMEWORKS_DIR"
cp "$BUILD_BINARY" "$APP_BINARY"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$ICON_FILE" "$APP_RESOURCES/CodexStudio.icns"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$THEME_PACKS_DIR" "$APP_RESOURCES/ThemePacks"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$DREAM_SKIN_RUNTIME_DIR" "$APP_RESOURCES/DreamSkinRuntime"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$DOCKDOOR_LAUNCHER_DIR" "$APP_RESOURCES/CodexThemedLauncherTemplate"
mkdir -p "$APP_RESOURCES/CodexThemedLauncherTemplate/Contents/Resources"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$ICON_FILE" "$APP_RESOURCES/CodexThemedLauncherTemplate/Contents/Resources/CodexStudio.icns"
chmod +x "$APP_RESOURCES/CodexThemedLauncherTemplate/Contents/MacOS/CodexThemedLauncher"
chmod +x "$APP_BINARY"

install_name_tool \
  -change "@rpath/Sparkle.framework/Versions/B/Sparkle" \
  "@loader_path/../Frameworks/Sparkle.framework/Versions/B/Sparkle" \
  "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Codex Studio</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>CodexStudio</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Codex Studio</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUAutomaticallyUpdate</key>
  <false/>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_ED_KEY</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -replace CFBundleShortVersionString -string "$APP_VERSION" \
  "$APP_RESOURCES/CodexThemedLauncherTemplate/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "$BUILD_NUMBER" \
  "$APP_RESOURCES/CodexThemedLauncherTemplate/Contents/Info.plist"

# File-provider locations can restore Finder metadata while a bundle is being
# assembled. Those attributes are not part of the shipped app and make
# codesign reject Sparkle's nested nibs and helper apps as resource forks.
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
xattr -dr com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
xattr -dr 'com.apple.fileprovider.fpfs#P' "$APP_BUNDLE" 2>/dev/null || true
# Recursive xattr removal does not clear the bundle directory itself on some
# File Provider-backed workspaces; clear the root too before signing.
xattr -c "$APP_BUNDLE" 2>/dev/null || true
while IFS= read -r -d '' bundle_path; do
  # Clear the complete attribute set on every node. Sparkle contains nested
  # helper bundles whose Finder/File Provider metadata can otherwise make the
  # outer signature invalid even after a targeted delete.
  xattr -c "$bundle_path" 2>/dev/null || true
done < <(find "$APP_BUNDLE" -depth -print0)

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
    echo "Warning: release bundle is ad-hoc signed; set CODEX_STUDIO_SIGNING_IDENTITY for distribution." >&2
  fi
  codesign --force --sign - "$APP_RESOURCES/CodexThemedLauncherTemplate"
  codesign --force --deep --sign - "$FRAMEWORKS_DIR/Sparkle.framework"
  codesign --force --deep --sign - "$APP_BUNDLE"
else
  if [[ "$BUILD_CONFIGURATION" == "release" || "$SIGNING_IDENTITY" == Developer\ ID\ Application:* ]]; then
    TIMESTAMP_ARGUMENT="--timestamp"
  else
    TIMESTAMP_ARGUMENT="--timestamp=none"
  fi
  codesign --force --options runtime "$TIMESTAMP_ARGUMENT" --sign "$SIGNING_IDENTITY" "$APP_RESOURCES/CodexThemedLauncherTemplate"
  codesign --force --deep --options runtime "$TIMESTAMP_ARGUMENT" --sign "$SIGNING_IDENTITY" "$FRAMEWORKS_DIR/Sparkle.framework"
  codesign --force --deep --options runtime "$TIMESTAMP_ARGUMENT" --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build|--build)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    codesign --verify --deep --strict "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|build|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
