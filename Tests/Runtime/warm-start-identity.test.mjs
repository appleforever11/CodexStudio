import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

async function scenario(emptyTime) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'studio-warm-start-'));
  try {
    await fs.copyFile(new URL('../../Resources/DreamSkinRuntime/scripts/start-dream-skin-macos.sh', import.meta.url), path.join(root, 'start.sh'));
    await fs.writeFile(path.join(root, 'injector.mjs'), 'process.exit(0)');
    await fs.writeFile(path.join(root, 'common-macos.sh'), `
SCRIPT_DIR="$TEST_ROOT"
STATE_PATH="$TEST_ROOT/missing-state"
START_ERROR_LOG="$TEST_ROOT/errors"
INJECTOR_ERROR_LOG="$TEST_ROOT/injector-errors"
INJECTOR="$TEST_ROOT/injector.mjs"
CODEX_BUNDLE="$TEST_ROOT/nonexistent.app"
NODE="$TEST_NODE"
SKIN_VERSION="test"
ensure_state_root() { :; }
new_operation_token() { echo test; }
write_operation_state() { :; }
dreamskin_text() { echo "$1"; }
discover_codex_app() { :; }
require_signed_node_runtime() { :; }
verified_cdp_endpoint() { return 0; }
begin_client_operation() { :; }
finish_client_operation() { :; }
verify_macos_app_signature() { :; }
codex_is_running() { return 0; }
launch_injector_daemon() { echo "$TEST_PID"; }
process_started_at() { [ "$TEST_EMPTY_TIME" = true ] || echo 'verified process start'; }
codex_main_pids() { echo 123; }
write_state() { printf '%s' "$3" > "$TEST_ROOT/recorded-time"; }
mark_state_active() { :; }
fail() { echo "$*" >&2; exit 1; }
`);
    let code = 0;
    try {
      execFileSync('/bin/bash', [path.join(root, 'start.sh'), '--port', '9341'], {
        env: { ...process.env, TEST_ROOT: root, TEST_NODE: process.execPath, TEST_PID: String(process.pid), TEST_EMPTY_TIME: String(emptyTime) },
        timeout: 5000, stdio: 'pipe',
      });
    } catch (error) { code = error.status; }
    return { code, recorded: await fs.readFile(path.join(root, 'recorded-time'), 'utf8').catch(() => null) };
  } finally { await fs.rm(root, { recursive: true, force: true }); }
}

test('warm launch records the watcher start time before publishing its state', async () => {
  assert.deepEqual(await scenario(false), { code: 0, recorded: 'verified process start' });
});

test('warm launch refuses to publish incomplete watcher identity', async () => {
  const result = await scenario(true);
  assert.notEqual(result.code, 0);
  assert.equal(result.recorded, null);
});
