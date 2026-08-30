#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-${CODEX_STUDIO_VERSION:-0.1.0}}"
ARCHIVE_PATH="${2:-$ROOT_DIR/dist/CodexStudio-${VERSION}-arm64.zip}"
OUTPUT_PATH="${3:-$ROOT_DIR/appcast.xml}"
REPOSITORY="${CODEX_STUDIO_REPOSITORY:-appleforever11/CodexStudio}"
SPARKLE_ACCOUNT="${CODEX_STUDIO_SPARKLE_ACCOUNT:-ed25519}"
SPARKLE_BIN="${SPARKLE_BIN_PATH:-$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin}"
INPUT_DIR="$(mktemp -d /tmp/codexstudio-appcast.XXXXXX)"

cleanup() {
  rm -rf "$INPUT_DIR"
}
trap cleanup EXIT

if [[ ! -x "$SPARKLE_BIN/generate_appcast" ]]; then
  echo "Sparkle generate_appcast was not found. Run swift package resolve first." >&2
  exit 1
fi
if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Sparkle archive was not found: $ARCHIVE_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
cp "$ARCHIVE_PATH" "$INPUT_DIR/CodexStudio-${VERSION}-arm64.zip"
cp "$ROOT_DIR/RELEASE_NOTES/${VERSION}.md" "$INPUT_DIR/CodexStudio-${VERSION}-arm64.md"

if [[ -f "$OUTPUT_PATH" ]]; then
  cp "$OUTPUT_PATH" "$INPUT_DIR/appcast.xml"
fi

APPCAST_ARGS=(
  --embed-release-notes
  --download-url-prefix "https://github.com/$REPOSITORY/releases/download/v${VERSION}/"
  --link "https://github.com/$REPOSITORY"
)

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN/generate_appcast" \
    --ed-key-file - \
    "${APPCAST_ARGS[@]}" \
    "$INPUT_DIR"
elif [[ -n "${CODEX_STUDIO_SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  "$SPARKLE_BIN/generate_appcast" \
    --ed-key-file "$CODEX_STUDIO_SPARKLE_PRIVATE_KEY_FILE" \
    "${APPCAST_ARGS[@]}" \
    "$INPUT_DIR"
else
  "$SPARKLE_BIN/generate_appcast" \
    --account "$SPARKLE_ACCOUNT" \
    "${APPCAST_ARGS[@]}" \
    "$INPUT_DIR"
fi

cp "$INPUT_DIR/appcast.xml" "$OUTPUT_PATH"
echo "APPCAST_PATH=$OUTPUT_PATH"
