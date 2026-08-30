#!/bin/bash

set -euo pipefail
export LC_ALL=C
export LANG=C
export LC_CTYPE=C
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
VERSION="$(/usr/bin/tr -d '[:space:]' < "$ROOT/VERSION")"
OUTPUT="${1:-$HOME/Desktop/Codex Theme Studio.zip}"
TMP="$(/usr/bin/mktemp -d /tmp/codex-dream-client.XXXXXX)"
CLIENT_ROOT="$TMP/Codex Theme Studio"
ENGINE="$CLIENT_ROOT/.codex-dream-skin-studio"
trap '/bin/rm -rf "$TMP"' EXIT

"$ROOT/tests/run-tests.sh"
/bin/mkdir -p "$ENGINE"
/usr/bin/rsync -a \
  --exclude '.git/' \
  --exclude '.DS_Store' \
  --exclude 'release/' \
  --exclude 'runtime/' \
  --exclude 'presets/preset-arina-hashimoto/' \
  "$ROOT/" "$ENGINE/"

# Keep the customer ZIP self-contained: bundle prompt docs and referenced
# images, then translate repository paths for the hidden standalone engine.
"$ROOT/scripts/prepare-standalone-docs.sh" "$ENGINE"
STANDALONE_README="$ENGINE/README.md"
if [ -f "$STANDALONE_README" ]; then
  temporary="${STANDALONE_README}.standalone"
  /usr/bin/sed \
    -e 's#\.\./docs/#docs/#g' \
    -e 's#\.\./windows/#https://github.com/Fei-Away/Codex-Dream-Skin/tree/main/windows/#g' \
    "$STANDALONE_README" > "$temporary"
  /bin/mv "$temporary" "$STANDALONE_README"
fi
PRESET_README="$ENGINE/presets/README.md"
if [ -f "$PRESET_README" ]; then
  temporary="${PRESET_README}.standalone"
  /usr/bin/sed -e 's#\.\./\.\./docs/#../docs/#g' "$PRESET_README" > "$temporary"
  /bin/mv "$temporary" "$PRESET_README"
fi

/usr/bin/printf '%s\n' \
  '#!/bin/bash' \
  'set -euo pipefail' \
  'ROOT="$(cd "$(dirname "$0")" && pwd -P)"' \
  'exec "$ROOT/.codex-dream-skin-studio/scripts/install-dream-skin-macos.sh"' \
  > "$CLIENT_ROOT/Install Codex Theme Studio.command"

/usr/bin/printf '%s\n' \
  "Codex Theme Studio $VERSION" \
  '' \
  'Recommended: send this complete ZIP, your preferred image, and "Codex deployment prompt.md" to your own Codex session.' \
  '' \
  'Manual installation: double-click "Install Codex Theme Studio.command". After installation, the desktop includes launch, customize, verify, and restore shortcuts.' \
  '' \
  'Do not copy only the image or CSS. The hidden .codex-dream-skin-studio directory is the complete runtime engine and must remain intact.' \
  > "$CLIENT_ROOT/Instructions.txt"

/bin/cp "$ROOT/CLIENT_DEPLOY_PROMPT.md" "$CLIENT_ROOT/Codex deployment prompt.md"
/bin/chmod 755 "$CLIENT_ROOT/Install Codex Theme Studio.command"
/bin/chmod 755 "$ENGINE"/*.command "$ENGINE"/scripts/*.sh "$ENGINE"/tests/*.sh
/usr/bin/find "$CLIENT_ROOT" -type f \( -name '.DS_Store' -o -name '._*' \) -delete
[ ! -e "$ENGINE/presets/preset-arina-hashimoto" ] \
  || { printf 'Restricted Arina preset entered the standalone ZIP.\n' >&2; exit 1; }
if /usr/bin/find "$CLIENT_ROOT" -type f -name 'arina-hashimoto-*' -print -quit | /usr/bin/grep -q .; then
  printf 'Restricted Arina documentation asset entered the standalone ZIP.\n' >&2
  exit 1
fi
/bin/mkdir -p "$(dirname "$OUTPUT")"
/bin/rm -f "$OUTPUT"
COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --keepParent --norsrc --noextattr "$CLIENT_ROOT" "$OUTPUT"
SHA256="$(/usr/bin/shasum -a 256 "$OUTPUT" | /usr/bin/awk '{print $1}')"
/usr/bin/printf 'Created %s\nSHA-256 %s\n' "$OUTPUT" "$SHA256"
