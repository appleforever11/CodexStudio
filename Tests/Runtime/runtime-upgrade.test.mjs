import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const script = fileURLToPath(new URL(
  "../../Resources/DreamSkinRuntime/scripts/common/injector-macos.sh", import.meta.url,
));

async function simulateUpgrade(stopFails) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "studio-runtime-upgrade-"));
  try {
    const log = path.join(root, "events");
    const node = path.join(root, "fake-node");
    await fs.writeFile(node, '#!/bin/bash\nprintf "inject\\n" >> "$TEST_LOG"\n', { mode: 0o700 });
    const harness = `
      source "$TEST_SCRIPT"
      SKIN_VERSION=1.9.7
      INJECTOR="$TEST_ROOT/injector.mjs"
      THEME_DIR="$TEST_ROOT/theme"
      NODE="$TEST_NODE"
      ensure_node_runtime() { return 0; }
      verified_cdp_endpoint() { return 0; }
      new_operation_token() { echo upgrade-test; }
      dreamskin_text() { echo "$1"; }
      write_operation_state() { return 0; }
      state_field() {
        case "$1" in
          injectorProtocol) echo 3 ;;
          injectorMode) echo theme ;;
          skinVersion) echo 1.9.5 ;;
        esac
      }
      stop_recorded_injector() { echo stop >> "$TEST_LOG"; return "$TEST_STOP_CODE"; }
      launch_injector_daemon() { echo launch >> "$TEST_LOG"; echo $$; }
      process_started_at() { echo test-start; }
      codex_main_pids() { echo 0; }
      write_state() { echo state >> "$TEST_LOG"; }
      mark_state_active() { echo reuse >> "$TEST_LOG"; }
      hot_reapply_theme 9341 1000 upgrade-test
      echo "result:$?" >> "$TEST_LOG"
    `;
    execFileSync("/bin/bash", ["-c", harness], {
      env: { ...process.env, TEST_ROOT: root, TEST_LOG: log, TEST_SCRIPT: script,
        TEST_NODE: node, TEST_STOP_CODE: stopFails ? "1" : "0" },
      timeout: 5000,
    });
    return (await fs.readFile(log, "utf8")).trim().split("\n");
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
}

test("an older watcher stops before the upgraded payload is installed", async () => {
  assert.deepEqual(await simulateUpgrade(false), ["stop", "inject", "launch", "state", "result:0"]);
});

test("an unverified watcher stop prevents an upgrade from racing the old engine", async () => {
  assert.deepEqual(await simulateUpgrade(true), ["stop", "result:1"]);
});
