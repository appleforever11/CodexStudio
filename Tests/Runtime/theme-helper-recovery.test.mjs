import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
const source = new URL('../../Resources/DreamSkinRuntime/scripts/recover-theme-once-macos.sh',import.meta.url);
async function probe({endpoint=true,ready=false,running=true,enabled=true,busy=false}={}) {
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'studio-helper-probe-'));
 try {
  await fs.copyFile(source,path.join(root,'recover.sh'));
  await fs.writeFile(path.join(root,'theme-switch-lock-macos.sh'),'acquire_theme_switch_lock() { :; }\nrelease_theme_switch_lock() { :; }\n');
  await fs.mkdir(path.join(root,'theme'));
  await fs.writeFile(path.join(root,'theme/theme.json'),'{}');
  await fs.writeFile(path.join(root,'config.plist'),`<?xml version="1.0"?><plist version="1.0"><dict><key>enabled</key><${enabled}/><key>port</key><integer>9341</integer></dict></plist>`);
  await fs.writeFile(path.join(root,'operation.plist'),`<?xml version="1.0"?><plist version="1.0"><dict><key>status</key><string>${busy?'applying':'success'}</string></dict></plist>`);
  await fs.writeFile(path.join(root,'common-macos.sh'),`
SCRIPT_DIR="$TEST_ROOT"
STATE_ROOT="$TEST_ROOT"
THEME_DIR="$TEST_ROOT/theme"
THEME_PERSISTENCE_PATH="$TEST_ROOT/config.plist"
OPERATION_STATE_PATH="$TEST_ROOT/operation.plist"
THEME_PERSISTENCE_LOG="$TEST_ROOT/log"
ensure_state_root() { :; }
discover_codex_app() { :; }
new_operation_token() { echo test; }
codex_is_running() { return ${running?0:1}; }
verified_cdp_endpoint() { return ${endpoint?0:1}; }
theme_runtime_state_ready() { return ${ready?0:1}; }
`);
  await fs.writeFile(path.join(root,'start-dream-skin-macos.sh'),'#!/bin/bash\nprintf "%s\\n" "$*" > "$TEST_ROOT/call"\n',{mode:0o700});
  execFileSync('/bin/bash',[path.join(root,'recover.sh')],{env:{...process.env,TEST_ROOT:root},timeout:5000});
  return await fs.readFile(path.join(root,'call'),'utf8').catch(()=>null);
 } finally {await fs.rm(root,{recursive:true,force:true});}
}
test('helper reconnects to a live endpoint without requesting a restart',async()=>assert.equal(await probe(),'--port 9341\n'));
test('helper only requests a restart when the endpoint is unavailable',async()=>assert.equal(await probe({endpoint:false}),'--port 9341 --restart-existing\n'));
test('helper leaves healthy, closed, disabled and busy sessions alone',async()=>{
 for(const options of [{ready:true},{running:false},{enabled:false},{busy:true}]) assert.equal(await probe(options),null);
});
