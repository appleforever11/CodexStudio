import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';

const source = new URL('../../Resources/DreamSkinRuntime/scripts/', import.meta.url);
async function scenario(failNew) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'studio-switch-recovery-'));
  try {
    await fs.mkdir(path.join(root, 'themes/new'), {recursive:true});
    await fs.mkdir(path.join(root, 'theme'));
    for (const [dir,id] of [['themes/new','new'],['theme','old']]) {
      await fs.writeFile(path.join(root,dir,'theme.json'), JSON.stringify({id,name:id}));
      await fs.writeFile(path.join(root,dir,'art.png'), id);
    }
    await fs.copyFile(new URL('switch-theme-macos.sh',source),path.join(root,'switch.sh'));
    await fs.writeFile(path.join(root,'theme-switch-lock-macos.sh'), 'acquire_theme_switch_lock() { :; }\nrelease_theme_switch_lock() { :; }\n');
    await fs.writeFile(path.join(root,'common-macos.sh'), `
SCRIPT_DIR="$TEST_ROOT"
STATE_ROOT="$TEST_ROOT"
THEME_DIR="$TEST_ROOT/theme"
STATE_PATH="$TEST_ROOT/missing-state"
NODE="$TEST_NODE"
INJECTOR="$TEST_ROOT/injector.mjs"
ensure_state_root() { :; }
ensure_node_runtime() { :; }
new_operation_token() { echo test; }
write_operation_state() { :; }
finish_client_operation() { :; }
begin_client_operation() { :; }
verified_cdp_endpoint() { return 0; }
dreamskin_text() { echo "$1"; }
notify_user() { :; }
alert_user() { :; }
fail() { echo "$*" >&2; exit 1; }
hot_reapply_theme() {
  local id="$("$NODE" -p 'JSON.parse(require("fs").readFileSync(process.argv[1])).id' "$THEME_DIR/theme.json")"
  echo "$id" >> "$TEST_ROOT/applies"
  [ "$id" != new ] || [ "$TEST_FAIL_NEW" != true ]
}
`);
    await fs.writeFile(path.join(root,'stage-theme.mjs'), `import fs from 'node:fs';import path from 'node:path';const [src,dst]=process.argv.slice(2);for(const name of ['theme.json','art.png'])fs.copyFileSync(path.join(src,name),path.join(dst,name));console.log(JSON.stringify({image:'art.png',contentFingerprint:'a'.repeat(64)}));`);
    await fs.writeFile(path.join(root,'injector.mjs'), 'process.exit(0);');
    let code=0;
    try { execFileSync('/bin/bash',[path.join(root,'switch.sh'),'--id','new'],{env:{...process.env,TEST_ROOT:root,TEST_NODE:process.execPath,TEST_FAIL_NEW:String(failNew)},timeout:30000,stdio:'pipe'}); }
    catch(e) {code=e.status;}
    return {code,theme:JSON.parse(await fs.readFile(path.join(root,'theme/theme.json'),'utf8')).id,applies:(await fs.readFile(path.join(root,'applies'),'utf8')).trim().split('\n')};
  } finally { await fs.rm(root,{recursive:true,force:true}); }
}
test('a failed connected apply restores and reinjects the previous theme without restarting',async()=>{
  assert.deepEqual(await scenario(true),{code:1,theme:'old',applies:['new','old']});
});
test('a verified switch retains the newly selected theme',async()=>{
  assert.deepEqual(await scenario(false),{code:0,theme:'new',applies:['new']});
});
