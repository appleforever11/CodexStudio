import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {dumpDOM} from './support/headless-html.mjs';
import {workspaceDefaults} from '../../Resources/DreamSkinRuntime/scripts/injector/workspace-preferences.mjs';
const browser=process.env.DREAM_SKIN_TEST_CHROMIUM || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const available=await fs.access(browser).then(()=>true,()=>false);
test('direct chat controls preserve native actions and clean up', {skip:!available,timeout:30000},async()=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'workspace-ui-'));
 try {
  const base=new URL('../../Resources/DreamSkinRuntime/assets/',import.meta.url);
  const scripts=await Promise.all(['workspace-controls','workspace-reading','workspace-navigation','workspace','direct-workspace'].map(n=>fs.readFile(new URL(`renderer/${n}.js`,base),'utf8')));
  const css=(await Promise.all(['task','workspace','direct-workspace'].map(name=>fs.readFile(new URL(`dream-skin/${name}.css`,base),'utf8')))).join('\n');
  const fixture=await fs.readFile(new URL('./fixtures/direct-workspace.html',import.meta.url),'utf8');
  const file=path.join(root,'fixture.html');
  await fs.writeFile(file,fixture.replace('<!-- CSS -->',`<style>${css}</style>`).replace('/* SETTINGS */',JSON.stringify(workspaceDefaults)).replace('/* MODULES */',scripts.join('\n')));
  const output=await dumpDOM(browser,['--headless','--disable-gpu','--no-first-run','--no-default-browser-check','--disable-background-networking',`--user-data-dir=${root}/profile`,'--window-size=1440,900','--virtual-time-budget=2000','--dump-dom',pathToFileURL(file).href]);
  const report=output.match(/<pre id="report">([^<]+)<\/pre>/)?.[1];
  assert.ok(report);assert.deepEqual(JSON.parse(report),{pass:true});
 } finally {await fs.rm(root,{recursive:true,force:true});}
});
