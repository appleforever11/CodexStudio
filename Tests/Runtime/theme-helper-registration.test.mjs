import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
const source=new URL('../../Resources/DreamSkinRuntime/scripts/set-theme-persistence-macos.sh',import.meta.url);
async function register(native) {
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'studio-registration-'));
 try {
  await fs.mkdir(path.join(root,'Library/LaunchAgents'),{recursive:true});
  await fs.mkdir(path.join(root,'theme'));
  await fs.writeFile(path.join(root,'theme/theme.json'),'{}');
  await fs.writeFile(path.join(root,'native-theme-helper'),'approved');
  await fs.writeFile(path.join(root,'native-theme-helper.pid'),'4321');
  await fs.writeFile(path.join(root,'Library/LaunchAgents/com.codexthemes.theme-monitor.plist'),'old');
  await fs.writeFile(path.join(root,'common-macos.sh'),`
SCRIPT_DIR="$HOME"
STATE_ROOT="$HOME"
PROJECT_ROOT="$HOME"
INSTALL_ROOT="$HOME"
THEME_DIR="$HOME/theme"
THEME_PERSISTENCE_PATH="$HOME/config.plist"
THEME_PERSISTENCE_JOB_LABEL=com.codexthemes.theme-monitor
THEME_PERSISTENCE_AGENT="$HOME/Library/LaunchAgents/com.codexthemes.theme-monitor.plist"
THEME_PERSISTENCE_LOG="$HOME/log"
SKIN_VERSION=1.9.27
ensure_state_root() { :; }
fail() { echo "$*" >&2; exit 1; }
`);
  await fs.writeFile(path.join(root,'theme-monitor-macos.sh'),'#!/bin/bash\n',{mode:0o700});
  await fs.writeFile(path.join(root,'fake-lsof'),'#!/bin/bash\necho n/Applications/CodexStudio.app/Contents/Library/LoginItems/CodexStudioThemeHelper.app/Contents/MacOS/CodexStudioThemeHelper\n',{mode:0o700});
  await fs.writeFile(path.join(root,'fake-launchctl'),`#!/bin/bash
printf '%s\\n' "$*" >> "$HOME/events"
if [ "$1" = print ]; then
 case "$2" in
  */local.kevinhowe.CodexStudio.ThemeHelper) ${native?'echo "pid = 4321"; exit 0':'exit 1'} ;;
  *) [ -f "$HOME/loaded" ]; exit $? ;;
 esac
fi
if [ "$1" = bootstrap ]; then touch "$HOME/loaded"; fi
exit 0
`,{mode:0o700});
  const script=(await fs.readFile(source,'utf8')).replaceAll('/bin/launchctl','"$SCRIPT_DIR/fake-launchctl"').replaceAll('/usr/sbin/lsof','"$SCRIPT_DIR/fake-lsof"');
  await fs.writeFile(path.join(root,'set.sh'),script);
  execFileSync('/bin/bash',[path.join(root,'set.sh'),'--enabled','true','--theme-id','old'],{env:{...process.env,HOME:root},timeout:5000});
  return {events:await fs.readFile(path.join(root,'events'),'utf8'),agent:await fs.access(path.join(root,'Library/LaunchAgents/com.codexthemes.theme-monitor.plist')).then(()=>true,()=>false)};
 } finally {await fs.rm(root,{recursive:true,force:true});}
}
test('registered native helper retires the legacy agent without bootstrapping it',async()=>{
 const result=await register(true);assert.equal(result.agent,false);assert.doesNotMatch(result.events,/bootstrap/);
});
test('a stale native marker falls back to a confirmed legacy job',async()=>{
 const result=await register(false);assert.equal(result.agent,true);assert.match(result.events,/bootstrap/);
});
