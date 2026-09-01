# Persistent launcher state read/write helpers.

state_field() {
  local key="$1"
  ensure_node_runtime
  "$NODE" -e '
    const fs = require("node:fs");
    const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8"))[process.argv[2]];
    if (value !== undefined && value !== null) process.stdout.write(String(value));
  ' "$STATE_PATH" "$key"
}

write_state() {
  local port="$1"
  local injector_pid="$2"
  local injector_started_at="$3"
  local codex_pid="$4"
  local session="${5:-applying}"
  local node_ver="${NODE_VERSION:-unknown}"
  local bundle="${CODEX_BUNDLE:-}"
  local exe="${CODEX_EXE:-}"
  local app_ver="${CODEX_VERSION:-}"
  local team="${CODEX_TEAM_ID:-}"
  "$NODE" -e '
    const fs = require("node:fs");
    const [file, version, port, pid, startedAt, injector, node, nodeVersion, bundle, exe, appVersion, teamId, root, themeDir, codexPid, arch, session] = process.argv.slice(1);
    const state = {
      schemaVersion: 4,
      platform: `darwin-${arch}`,
      skinVersion: version,
      injectorProtocol: 3,
      port: Number(port),
      injectorPid: Number(pid),
      injectorStartedAt: startedAt,
      injectorPath: injector,
      nodePath: node,
      nodeVersion,
      codexBundle: bundle,
      codexExe: exe,
      codexVersion: appVersion,
      codexTeamId: teamId,
      codexPid: Number(codexPid || 0),
      projectRoot: root,
      themeDir,
      session,
      injectorMode: "full",
      createdAt: new Date().toISOString()
    };
    if (session === "active") {
      try {
        const theme = JSON.parse(fs.readFileSync(`${themeDir}/theme.json`, "utf8"));
        state.appliedThemeId = String(theme.id || "");
        state.appliedThemeName = String(theme.name || theme.id || "");
        state.verifiedAt = new Date().toISOString();
      } catch {}
    }
    const temporary = `${file}.${process.pid}.tmp`;
    fs.writeFileSync(temporary, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
    fs.renameSync(temporary, file);
  ' "$STATE_PATH" "$SKIN_VERSION" "$port" "$injector_pid" "$injector_started_at" "$INJECTOR" "$NODE" "$node_ver" "$bundle" "$exe" "$app_ver" "$team" "$PROJECT_ROOT" "$THEME_DIR" "$codex_pid" "$(/usr/bin/uname -m)" "$session"
}

mark_state_active() {
  [ -f "$STATE_PATH" ] || return 1
  "$NODE" -e '
    const fs = require("node:fs");
    const [file, themeDir] = process.argv.slice(1);
    const state = JSON.parse(fs.readFileSync(file, "utf8"));
    const theme = JSON.parse(fs.readFileSync(`${themeDir}/theme.json`, "utf8"));
    state.session = "active";
    state.appliedThemeId = String(theme.id || "");
    state.appliedThemeName = String(theme.name || theme.id || "");
    state.injectorMode = "full";
    delete state.pausedAt;
    state.verifiedAt = new Date().toISOString();
    state.updatedAt = state.verifiedAt;
    const temporary = `${file}.${process.pid}.tmp`;
    fs.writeFileSync(temporary, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
    fs.renameSync(temporary, file);
  ' "$STATE_PATH" "$THEME_DIR"
}

mark_state_stale() {
  [ -f "$STATE_PATH" ] || return 0
  "$NODE" -e '
    const fs = require("node:fs");
    const file = process.argv[1];
    const state = JSON.parse(fs.readFileSync(file, "utf8"));
    state.session = "stale";
    state.updatedAt = new Date().toISOString();
    const temporary = `${file}.${process.pid}.tmp`;
    fs.writeFileSync(temporary, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
    fs.renameSync(temporary, file);
  ' "$STATE_PATH"
}
