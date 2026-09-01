# Preset seeding and signed Codex application discovery.

# Seed bundled preset packs into the user's themes/ library so a fresh install
# ships with ready-to-use skins. Idempotent (each preset is refreshed in place)
# and scoped to preset-* ids, so user-made custom-* packs are never touched.
seed_bundled_presets() {
  local presets_root="$PROJECT_ROOT/presets"
  [ -d "$presets_root" ] || return 0
  local themes_root="$STATE_ROOT/themes"
  /bin/mkdir -p "$themes_root"
  local retired
  for retired in \
    preset-midnight-aurora preset-sakura-dawn preset-amber-dusk \
    preset-forest-mist preset-cyber-neon preset-romantic-rose; do
    /bin/rm -rf "$themes_root/$retired"
  done
  local src id dest entry
  for src in "$presets_root"/preset-*/; do
    [ -d "$src" ] || continue
    [ -f "${src}theme.json" ] || continue
    id="$(/usr/bin/basename "$src")"
    dest="$themes_root/$id"
    /bin/rm -rf "$dest"
    /bin/mkdir -p "$dest"
    /bin/chmod 700 "$dest"
    for entry in "$src"*; do
      [ -f "$entry" ] || continue
      /bin/cp "$entry" "$dest/"
    done
    /bin/chmod 600 "$dest"/* 2>/dev/null || true
  done
}

discover_codex_app() {
  local candidate=""
  local identifier=""
  local executable_name=""
  local configured="${CODEX_APP_BUNDLE:-}"

  CODEX_BUNDLE=""
  for candidate in "$configured" \
    "/Applications/ChatGPT.app" "$HOME/Applications/ChatGPT.app" \
    "/Applications/Codex.app" "$HOME/Applications/Codex.app"; do
    [ -n "$candidate" ] || continue
    [ -f "$candidate/Contents/Info.plist" ] || continue
    identifier="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$candidate/Contents/Info.plist" 2>/dev/null || true)"
    if [ "$identifier" = "com.openai.codex" ]; then
      CODEX_BUNDLE="$candidate"
      break
    fi
  done

  if [ -z "${CODEX_BUNDLE:-}" ]; then
    candidate="$(/usr/bin/mdfind 'kMDItemCFBundleIdentifier == "com.openai.codex"' | /usr/bin/head -n 1)"
    if [ -n "$candidate" ] && [ -f "$candidate/Contents/Info.plist" ]; then
      identifier="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$candidate/Contents/Info.plist" 2>/dev/null || true)"
      [ "$identifier" = "com.openai.codex" ] && CODEX_BUNDLE="$candidate"
    fi
  fi

  [ -n "${CODEX_BUNDLE:-}" ] || fail "Could not find the official ChatGPT app bundle (com.openai.codex)."
  executable_name="$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$CODEX_BUNDLE/Contents/Info.plist")"
  CODEX_EXE="$CODEX_BUNDLE/Contents/MacOS/$executable_name"
  CODEX_VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$CODEX_BUNDLE/Contents/Info.plist")"
  [ -x "$CODEX_EXE" ] || fail "ChatGPT executable is missing: $CODEX_EXE"
  export CODEX_BUNDLE CODEX_EXE CODEX_VERSION
}

codesign_team_id() {
  /usr/bin/codesign -dv --verbose=4 "$1" 2>&1 \
    | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}'
}

remember_validated_runtime_identity() {
  DREAM_SKIN_VALIDATED_RUNTIME_PID="$$"
  DREAM_SKIN_VALIDATED_RUNTIME_BUNDLE="$CODEX_BUNDLE"
  DREAM_SKIN_VALIDATED_RUNTIME_EXE="$CODEX_EXE"
  DREAM_SKIN_VALIDATED_RUNTIME_NODE="$NODE"
}

require_signed_node_runtime() {
  [ "$(/usr/bin/uname -s)" = "Darwin" ] || fail "This launcher requires macOS."
  [ -n "${CODEX_BUNDLE:-}" ] && [ -n "${CODEX_EXE:-}" ] \
    || fail "Discover the ChatGPT app before validating its runtime."

  RUNTIME_NODE="$CODEX_BUNDLE/Contents/Resources/cua_node/bin/node"
  [ -x "$RUNTIME_NODE" ] || fail "The signed Node.js runtime bundled with ChatGPT was not found: $RUNTIME_NODE"
  /usr/bin/codesign --verify --strict \
    --test-requirement "=$EXPECTED_CODEX_REQUIREMENT" "$RUNTIME_NODE" >/dev/null 2>&1 \
    || fail "The Node.js runtime bundled with ChatGPT failed code-signature validation."

  CODEX_TEAM_ID="$(codesign_team_id "$CODEX_BUNDLE")"
  NODE_TEAM_ID="$(codesign_team_id "$RUNTIME_NODE")"
  [ "$CODEX_TEAM_ID" = "$EXPECTED_CODEX_TEAM_ID" ] \
    || fail "Unexpected ChatGPT signing team: ${CODEX_TEAM_ID:-missing}."
  [ "$NODE_TEAM_ID" = "$EXPECTED_CODEX_TEAM_ID" ] \
    || fail "Unexpected bundled Node.js signing team: ${NODE_TEAM_ID:-missing}."

  local machine_arch
  local node_major
  machine_arch="$(/usr/bin/uname -m)"
  /usr/bin/file "$RUNTIME_NODE" | /usr/bin/grep -q "$machine_arch" \
    || fail "The ChatGPT Node.js runtime does not match this Mac architecture ($machine_arch)."
  NODE_VERSION="$($RUNTIME_NODE --version)"
  node_major="${NODE_VERSION#v}"
  node_major="${node_major%%.*}"
  case "$node_major" in ''|*[!0-9]*) fail "Could not parse bundled Node.js version: $NODE_VERSION" ;; esac
  [ "$node_major" -ge 20 ] || fail "ChatGPT bundled Node.js $NODE_VERSION is too old; version 20 or newer is required."

  NODE="$RUNTIME_NODE"
  export NODE RUNTIME_NODE NODE_VERSION CODEX_TEAM_ID NODE_TEAM_ID
  remember_validated_runtime_identity
}

verify_macos_app_signature() {
  local verification_mode="${1:-deep}"
  case "$verification_mode" in deep|quick) ;; *) fail "Unknown runtime verification mode: $verification_mode" ;; esac
  if [ "$verification_mode" = "deep" ]; then
    /usr/bin/codesign --verify --deep --strict \
      --test-requirement "=$EXPECTED_CODEX_REQUIREMENT" "$CODEX_BUNDLE" >/dev/null 2>&1 \
      || fail "The ChatGPT app signature is not valid. Restore or reinstall the official app before continuing."
  else
    /usr/bin/codesign --verify --strict \
      --test-requirement "=$EXPECTED_CODEX_REQUIREMENT" "$CODEX_BUNDLE" >/dev/null 2>&1 \
      || fail "The ChatGPT app signature is not valid. Restore or reinstall the official app before continuing."
  fi
}

require_macos_runtime() {
  local verification_mode="${1:-deep}"
  require_signed_node_runtime
  verify_macos_app_signature "$verification_mode"
}
