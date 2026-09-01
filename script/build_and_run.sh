#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CodexStudio"
BUNDLE_ID="local.kevinhowe.CodexStudio"
MIN_SYSTEM_VERSION="14.0"
BUILD_CONFIGURATION="${CODEX_STUDIO_BUILD_CONFIGURATION:-debug}"
APP_VERSION="${CODEX_STUDIO_VERSION:-0.1.0}"
INCLUDE_LOCAL_ONLY_THEMES="${CODEX_STUDIO_INCLUDE_LOCAL_ONLY_THEMES:-}"
if [[ -z "$INCLUDE_LOCAL_ONLY_THEMES" ]]; then
  if [[ "$BUILD_CONFIGURATION" == "debug" ]]; then
    INCLUDE_LOCAL_ONLY_THEMES="true"
  else
    INCLUDE_LOCAL_ONLY_THEMES="false"
  fi
fi
if [[ -n "${CODEX_STUDIO_BUILD_NUMBER:-}" ]]; then
  BUILD_NUMBER="$CODEX_STUDIO_BUILD_NUMBER"
else
  IFS='.' read -r VERSION_MAJOR VERSION_MINOR VERSION_PATCH <<< "$APP_VERSION"
  # Keep Sparkle's monotonically increasing build-number scale aligned with
  # the versions already published in the appcast (0.1.5 -> 1005000).
  BUILD_NUMBER="$((10#${VERSION_MAJOR:-0} * 1000000000 + 10#${VERSION_MINOR:-0} * 1000000 + 10#${VERSION_PATCH:-0} * 1000))"
fi
SIGNING_IDENTITY="${CODEX_STUDIO_SIGNING_IDENTITY:-}"
SPARKLE_FEED_URL="${CODEX_STUDIO_SPARKLE_FEED_URL:-https://github.com/appleforever11/CodexStudio/releases/latest/download/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${CODEX_STUDIO_SPARKLE_PUBLIC_ED_KEY:-1QwxGTbkRZRB2hZJ8wTAJwytcGxG1v5i9/l/oEVuPzg=}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_HOME="${HOME:-}"
if [[ -z "$USER_HOME" ]]; then
  echo "The user's home directory could not be resolved for the local theme cache." >&2
  exit 1
fi
# Keep interactive builds outside File Provider-backed workspaces. Those
# locations continuously attach Finder metadata to nested Sparkle bundles and
# can invalidate an otherwise-correct signature while codesign is running.
# Release scripts already provide their own isolated CODEX_STUDIO_DIST_DIR.
LOCAL_BUILD_DIR="${TMPDIR%/}/codex-studio-local-build"
DIST_DIR="${CODEX_STUDIO_DIST_DIR:-$LOCAL_BUILD_DIR}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_FILE="$ROOT_DIR/Resources/CodexStudio.icns"
THEMED_LAUNCHER_ICON_FILE="$ROOT_DIR/Resources/CodexDark.icns"
DOCKDOOR_ICON_FILE="$ROOT_DIR/Resources/CodexDarkDockDoor.icns"
THEME_PACKS_DIR="$ROOT_DIR/Resources/ThemePacks"
DREAM_SKIN_RUNTIME_DIR="$ROOT_DIR/Resources/DreamSkinRuntime"
DOCKDOOR_LAUNCHER_DIR="$ROOT_DIR/Resources/CodexThemedLauncherTemplate"
FRAMEWORKS_DIR="$APP_CONTENTS/Frameworks"
THEME_CACHE_DIR="${CODEX_STUDIO_THEME_CACHE_DIR:-$USER_HOME/Library/Application Support/CodexStudio/ThemePacks}"
LOCAL_BUILD_ASSETS_DIR="${CODEX_STUDIO_BUILD_ASSET_CACHE_DIR:-$USER_HOME/Library/Application Support/CodexStudio/BuildAssets}"
LOCAL_RUNTIME_DIR="$LOCAL_BUILD_ASSETS_DIR/DreamSkinRuntime"
LOCAL_LAUNCHER_DIR="$LOCAL_BUILD_ASSETS_DIR/CodexThemedLauncherTemplate"
LOCAL_ICON_FILE="$LOCAL_BUILD_ASSETS_DIR/CodexStudio.icns"
LOCAL_THEMED_LAUNCHER_ICON_FILE="$LOCAL_BUILD_ASSETS_DIR/CodexDark.icns"
LOCAL_DOCKDOOR_ICON_FILE="$LOCAL_BUILD_ASSETS_DIR/CodexDarkDockDoor.icns"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  for identity_pattern in 'Developer ID Application' 'Apple Development'; do
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' -v pattern="$identity_pattern" '$0 ~ /^[[:space:]]*[0-9]+\)/ && index($2, pattern) {print $2; exit}')"
    [[ -n "$SIGNING_IDENTITY" ]] && break
  done
fi
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

# Stop only the bundle this build will replace. A name-only kill can miss a
# path-launched process, while rebuilding a live executable can leave dyld
# reading a partially replaced code page and surface as "Code Signature
# Invalid" on the next launch.
stop_existing_bundle_process() {
  local running_pid
  while IFS= read -r running_pid; do
    [[ -n "$running_pid" ]] || continue
    kill -TERM "$running_pid" >/dev/null 2>&1 || true
  done < <(pgrep -f -x "$APP_BINARY" 2>/dev/null || true)

  for _ in {1..20}; do
    if ! pgrep -f -x "$APP_BINARY" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done

  echo "The existing $APP_NAME process did not exit before its bundle was rebuilt." >&2
  exit 1
}

stop_existing_bundle_process

cd "$ROOT_DIR"
if [[ "${CODEX_STUDIO_SKIP_BUILD:-false}" == "true" ]]; then
  BUILD_BINARY="${CODEX_STUDIO_BUILD_BINARY:-$ROOT_DIR/.build/out/Products/Debug/$APP_NAME}"
  [[ -x "$BUILD_BINARY" ]] || {
    echo "The requested prebuilt binary was not found at $BUILD_BINARY." >&2
    exit 1
  }
else
  swift build --product "$APP_NAME" --configuration "$BUILD_CONFIGURATION"
  BUILD_BINARY="$(swift build --show-bin-path --configuration "$BUILD_CONFIGURATION")/$APP_NAME"
fi

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
# Keep build-critical files outside the iCloud-backed repository. A deliberate
# refresh is available for source changes, but normal builds only read this
# local mirror and never wait for File Provider to hydrate old assets.
REFRESH_LOCAL_BUILD_ASSETS="${CODEX_STUDIO_REFRESH_LOCAL_BUILD_ASSETS:-false}"
mkdir -p "$LOCAL_BUILD_ASSETS_DIR"
if [[ "$REFRESH_LOCAL_BUILD_ASSETS" == "true" || ! -d "$LOCAL_RUNTIME_DIR/scripts" ]]; then
  if [[ ! -d "$DREAM_SKIN_RUNTIME_DIR/scripts" ]]; then
    echo "Bundled Codex theme runtime was not found at $DREAM_SKIN_RUNTIME_DIR." >&2
    exit 1
  fi
  mkdir -p "$LOCAL_RUNTIME_DIR"
  rsync -a --delete --exclude '/presets/' "$DREAM_SKIN_RUNTIME_DIR/" "$LOCAL_RUNTIME_DIR/"
fi
if [[ "$REFRESH_LOCAL_BUILD_ASSETS" == "true" || ! -f "$LOCAL_LAUNCHER_DIR/Contents/Info.plist" || ! -f "$LOCAL_LAUNCHER_DIR/Contents/MacOS/CodexThemedLauncher" ]]; then
  if [[ ! -f "$DOCKDOOR_LAUNCHER_DIR/Contents/Info.plist" || ! -f "$DOCKDOOR_LAUNCHER_DIR/Contents/MacOS/CodexThemedLauncher" ]]; then
    echo "Bundled DockDoor launcher was not found at $DOCKDOOR_LAUNCHER_DIR." >&2
    exit 1
  fi
  mkdir -p "$LOCAL_LAUNCHER_DIR"
  rsync -a --delete "$DOCKDOOR_LAUNCHER_DIR/" "$LOCAL_LAUNCHER_DIR/"
fi
if [[ "$REFRESH_LOCAL_BUILD_ASSETS" == "true" || ! -f "$LOCAL_ICON_FILE" ]]; then
  if [[ ! -f "$ICON_FILE" ]]; then
    echo "The Codex Studio app icon was not found at $ICON_FILE." >&2
    exit 1
  fi
  COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$ICON_FILE" "$LOCAL_ICON_FILE"
fi
if [[ "$REFRESH_LOCAL_BUILD_ASSETS" == "true" || ! -f "$LOCAL_THEMED_LAUNCHER_ICON_FILE" ]]; then
  if [[ ! -f "$THEMED_LAUNCHER_ICON_FILE" ]]; then
    echo "The themed Codex launcher icon was not found at $THEMED_LAUNCHER_ICON_FILE." >&2
    exit 1
  fi
  COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$THEMED_LAUNCHER_ICON_FILE" "$LOCAL_THEMED_LAUNCHER_ICON_FILE"
fi
if [[ "$REFRESH_LOCAL_BUILD_ASSETS" == "true" || ! -f "$LOCAL_DOCKDOOR_ICON_FILE" ]]; then
  if [[ ! -f "$DOCKDOOR_ICON_FILE" ]]; then
    echo "The DockDoor-optimized Codex icon was not found at $DOCKDOOR_ICON_FILE." >&2
    exit 1
  fi
  COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$DOCKDOOR_ICON_FILE" "$LOCAL_DOCKDOOR_ICON_FILE"
fi

ICON_FILE="$LOCAL_ICON_FILE"
THEMED_LAUNCHER_ICON_FILE="$LOCAL_THEMED_LAUNCHER_ICON_FILE"
DOCKDOOR_ICON_FILE="$LOCAL_DOCKDOOR_ICON_FILE"
DREAM_SKIN_RUNTIME_DIR="$LOCAL_RUNTIME_DIR"
DOCKDOOR_LAUNCHER_DIR="$LOCAL_LAUNCHER_DIR"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$FRAMEWORKS_DIR"
cp "$BUILD_BINARY" "$APP_BINARY"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$ICON_FILE" "$APP_RESOURCES/CodexStudio.icns"
mkdir -p "$APP_RESOURCES/ThemePacks"
# Only provenance-verified, non-AI packs enter an app or DMG. Legacy local
# packages remain available in the source tree and user library without being
# misrepresented as release-ready artwork. Apple platform shelves are
# explicitly local-only because their underlying artwork is copyrighted.
# The repository is iCloud-backed, so maintain a persistent local mirror. New
# catalog-bearing folders are synchronized automatically; existing cached
# folders are reused without waking their iCloud image data. Set
# CODEX_STUDIO_REFRESH_THEME_CACHE=true when deliberately replacing an
# existing pack.
mkdir -p "$THEME_CACHE_DIR"
CANDIDATE_THEME_NAMES=()
THEME_SYNC_SOURCES=()
REFRESH_THEME_CACHE="${CODEX_STUDIO_REFRESH_THEME_CACHE:-false}"
while IFS= read -r catalog_file; do
  source_theme="${catalog_file%/catalog.json}"
  [[ -f "$source_theme/theme.json" && -f "$source_theme/LICENSE.txt" ]] || continue
  theme_name="$(basename "$source_theme")"
  local_only="$(/usr/bin/plutil -extract localOnly raw -o - "$catalog_file" 2>/dev/null || true)"
  if [[ "$local_only" != "true" ]]; then
    case "$theme_name" in
      macos-*|ios-*|ipados-*) local_only="true" ;;
      *) local_only="false" ;;
    esac
  fi
  if [[ "$local_only" == "true" && "$INCLUDE_LOCAL_ONLY_THEMES" != "true" ]]; then
    continue
  fi
  CANDIDATE_THEME_NAMES+=("$theme_name")
  cached_theme="$THEME_CACHE_DIR/$theme_name"
  if [[ "$local_only" == "true" ]]; then
    cached_image_url="$(/usr/bin/plutil -extract imageURL raw -o - "$cached_theme/catalog.json" 2>/dev/null || true)"
    source_image_url="$(/usr/bin/plutil -extract imageURL raw -o - "$catalog_file" 2>/dev/null || true)"
    if [[ ! -s "$cached_theme/background.jpg" || "$cached_image_url" != "$source_image_url" ]]; then
      echo "Local-only Apple wallpaper is not ready in the local cache: $theme_name. Run the matching official Apple wallpaper importer." >&2
      continue
    fi
  elif [[ "$REFRESH_THEME_CACHE" == "true" || ! -d "$cached_theme" ]]; then
    THEME_SYNC_SOURCES+=("$source_theme")
  fi
done < <(find "$THEME_PACKS_DIR" -mindepth 2 -maxdepth 2 -type f -name catalog.json -print)
if [[ "${#CANDIDATE_THEME_NAMES[@]}" -eq 0 ]]; then
  echo "No candidate theme packs were found in $THEME_PACKS_DIR; continuing with the local library." >&2
fi
THEME_COPY_JOBS="${CODEX_STUDIO_THEME_COPY_JOBS:-4}"
case "$THEME_COPY_JOBS" in
  ''|*[!0-9]*|0) THEME_COPY_JOBS=4 ;;
esac
[[ "$THEME_COPY_JOBS" -le 8 ]] || THEME_COPY_JOBS=8

copy_theme_sources() {
  local destination="$1"
  shift
  local -a sources=("$@")
  [[ "${#sources[@]}" -gt 0 ]] || return 0

  local chunk_size=$(((${#sources[@]} + THEME_COPY_JOBS - 1) / THEME_COPY_JOBS))
  local -a copy_pids=()
  local offset=0
  while [[ "$offset" -lt "${#sources[@]}" ]]; do
    local -a chunk=("${sources[@]:offset:chunk_size}")
    rsync -a "${chunk[@]}" "$destination/" &
    copy_pids+=("$!")
    offset=$((offset + chunk_size))
  done

  local copy_failed=0
  local copy_pid
  for copy_pid in "${copy_pids[@]}"; do
    wait "$copy_pid" || copy_failed=1
  done
  if [[ "$copy_failed" -ne 0 ]]; then
    return 1
  fi
}

if [[ "${#THEME_SYNC_SOURCES[@]}" -gt 0 ]]; then
  if ! copy_theme_sources "$THEME_CACHE_DIR" "${THEME_SYNC_SOURCES[@]}"; then
    echo "Local theme cache synchronization failed." >&2
    exit 1
  fi
fi

VERIFIED_THEME_SOURCES=()
for theme_name in "${CANDIDATE_THEME_NAMES[@]}"; do
  cached_theme="$THEME_CACHE_DIR/$theme_name"
  [[ -d "$cached_theme" ]] || continue
  VERIFIED_THEME_SOURCES+=("$cached_theme")
done
if [[ "${#VERIFIED_THEME_SOURCES[@]}" -eq 0 ]]; then
  echo "No cached theme packs were available; the app will use its managed local library." >&2
fi

if ! copy_theme_sources "$APP_RESOURCES/ThemePacks" "${VERIFIED_THEME_SOURCES[@]}"; then
  echo "Theme pack staging failed while copying the local assets." >&2
  exit 1
fi
VERIFIED_THEME_PACK_COUNT=0
for bundled_theme in "$APP_RESOURCES/ThemePacks"/*; do
  [[ -d "$bundled_theme" ]] || continue
  catalog_file="$bundled_theme/catalog.json"
  license_file="$bundled_theme/LICENSE.txt"
  if [[ ! -f "$bundled_theme/theme.json" || ! -f "$catalog_file" || ! -f "$license_file" ]]; then
    rm -rf "$bundled_theme"
    continue
  fi
  local_only="$(/usr/bin/plutil -extract localOnly raw -o - "$catalog_file" 2>/dev/null || true)"
  if [[ "$local_only" == "true" ]]; then
    if [[ "$INCLUDE_LOCAL_ONLY_THEMES" == "true" && -s "$bundled_theme/background.jpg" ]]; then
      VERIFIED_THEME_PACK_COUNT=$((VERIFIED_THEME_PACK_COUNT + 1))
      continue
    fi
    rm -rf "$bundled_theme"
    continue
  fi
  ai_generated="$(/usr/bin/plutil -extract aiGenerated raw -o - "$catalog_file" 2>/dev/null || true)"
  rights_status="$(/usr/bin/plutil -extract rightsStatus raw -o - "$catalog_file" 2>/dev/null || true)"
  source_url="$(/usr/bin/plutil -extract sourceURL raw -o - "$catalog_file" 2>/dev/null || true)"
  if [[ "$ai_generated" != "false" || -z "$source_url" ]]; then
    rm -rf "$bundled_theme"
    continue
  fi
  case "$rights_status" in
    *Public\ Domain*|*public\ domain*|*CC0*) ;;
    *) rm -rf "$bundled_theme"; continue ;;
  esac
  VERIFIED_THEME_PACK_COUNT=$((VERIFIED_THEME_PACK_COUNT + 1))
done
if [[ "$VERIFIED_THEME_PACK_COUNT" -eq 0 ]]; then
  echo "No distributable theme packs are bundled; local-only and managed themes remain available." >&2
fi

# The app owns its curated catalog. The embedded runtime only needs the engine;
# excluding its legacy preset snapshot prevents unverified art from leaking
# into the distributed bundle through a second hidden path.
mkdir -p "$APP_RESOURCES/DreamSkinRuntime"
rsync -a --delete --exclude '/presets/' "$DREAM_SKIN_RUNTIME_DIR/" "$APP_RESOURCES/DreamSkinRuntime/"
mkdir -p "$APP_RESOURCES/DreamSkinRuntime/presets"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$DOCKDOOR_LAUNCHER_DIR" "$APP_RESOURCES/CodexThemedLauncherTemplate"
mkdir -p "$APP_RESOURCES/CodexThemedLauncherTemplate/Contents/Resources"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$THEMED_LAUNCHER_ICON_FILE" "$APP_RESOURCES/CodexThemedLauncherTemplate/Contents/Resources/CodexDark.icns"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn "$DOCKDOOR_ICON_FILE" "$APP_RESOURCES/CodexThemedLauncherTemplate/Contents/Resources/CodexDarkDockDoor.icns"
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

# File Provider can reattach these two attributes to bundle directories while
# the recursive clear is walking the tree. Remove them once more, node by
# node, immediately before codesign. com.apple.provenance is system-managed
# and is harmless here; FinderInfo and fpfs metadata are not.
clear_signature_invalid_xattrs() {
  # Batch paths so File Provider has no multi-second window to reattach bundle
  # metadata between the clear and the following codesign invocation.
  find "$APP_BUNDLE" -depth -print0 \
    | xargs -0 -n 100 xattr -d com.apple.FinderInfo 2>/dev/null || true
  find "$APP_BUNDLE" -depth -print0 \
    | xargs -0 -n 100 xattr -d 'com.apple.fileprovider.fpfs#P' 2>/dev/null || true
}

clear_signature_invalid_xattrs

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
    echo "Warning: release bundle is ad-hoc signed; set CODEX_STUDIO_SIGNING_IDENTITY for distribution." >&2
  fi
  codesign --force --sign - "$APP_RESOURCES/CodexThemedLauncherTemplate"
  clear_signature_invalid_xattrs
  codesign --force --deep --sign - "$FRAMEWORKS_DIR/Sparkle.framework"
  clear_signature_invalid_xattrs
  codesign --force --deep --sign - "$APP_BUNDLE"
else
  if [[ "$BUILD_CONFIGURATION" == "release" || "$SIGNING_IDENTITY" == Developer\ ID\ Application:* ]]; then
    TIMESTAMP_ARGUMENT="--timestamp"
  else
    TIMESTAMP_ARGUMENT="--timestamp=none"
  fi
  codesign --force --options runtime "$TIMESTAMP_ARGUMENT" --sign "$SIGNING_IDENTITY" "$APP_RESOURCES/CodexThemedLauncherTemplate"
  clear_signature_invalid_xattrs
  codesign --force --deep --options runtime "$TIMESTAMP_ARGUMENT" --sign "$SIGNING_IDENTITY" "$FRAMEWORKS_DIR/Sparkle.framework"
  clear_signature_invalid_xattrs
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
