import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const source=fileURLToPath(new URL('../../Resources/DreamSkinRuntime/scripts/common/process-macos.sh',import.meta.url));
async function ready({session='active',theme='a',watcher=true,version='current'}={}) {
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'studio-health-'));
 try {
  await fs.writeFile(path.join(root,'state.json'),JSON.stringify({session,appliedThemeId:theme,codexPid:123}));
  await fs.writeFile(path.join(root,'theme.json'),JSON.stringify({id:'a'}));
  const result=execFileSync('/bin/bash',['-c',`
source "$TEST_SOURCE"
STATE_PATH="$TEST_ROOT/state.json"
THEME_DIR="$TEST_ROOT"
SKIN_VERSION=current
codex_main_pids() { echo 123; }
state_field() { [ "$1" != skinVersion ] || echo "$TEST_VERSION"; }
recorded_injector_process_matches() { [ "$TEST_WATCHER" = true ]; }
if theme_runtime_state_ready; then echo ready; else echo recover; fi
`],{env:{...process.env,TEST_SOURCE:source,TEST_ROOT:root,TEST_VERSION:version,TEST_WATCHER:String(watcher)},timeout:5000}).toString().trim();
  return result;
 } finally { await fs.rm(root,{recursive:true,force:true}); }
}
test('helper health rejects stale sessions, mismatched themes, dead watchers and older engines',async()=>{
 assert.equal(await ready(),'ready');
 for(const input of [{session:'paused'},{theme:'b'},{watcher:false},{version:'old'}]) assert.equal(await ready(input),'recover');
});
