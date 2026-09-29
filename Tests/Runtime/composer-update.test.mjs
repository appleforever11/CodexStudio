import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { dumpDOM } from './support/headless-html.mjs';
const browser = process.env.DREAM_SKIN_TEST_CHROMIUM || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const hasBrowser = await fs.access(browser).then(() => true, () => false);
const css = (await Promise.all(['tokens', 'composer', 'task'].map(name => fs.readFile(new URL(`../../Resources/DreamSkinRuntime/assets/dream-skin/${name}.css`, import.meta.url), 'utf8')))).join('\n');
test('26.928 home wrappers and solid thread backdrop retain one composer surface', {skip: !hasBrowser, timeout: 30000}, async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'dreamskin-composer-'));
  try {
    const page = path.join(dir, 'fixture.html');
    await fs.writeFile(page, `<html data-dream-skin="active" data-dream-art-wide="true"><style>
[data-composer-body],.bg-surface {background:rgb(54,54,54)}
[data-composer-body]{height:98px}[data-thread-scroll-footer]{position:relative;height:114px}
</style><style>${css}</style><body><main data-app-shell-main-surface="default"><div class="thread-scroll-container"><div class="pointer-events-none sticky bottom-0"><div id="fade" class="pointer-events-none absolute z-0 bg-gradient-to-t from-surface" style="background-image:linear-gradient(black,transparent)"></div></div></div>
<div id="legacy" class="_ComposerLayoutRoot_old" data-composer-utility-bar-variant="home"><div data-composer-body class="_ComposerLayoutBody_old"></div></div>
<div id="modern" class="_ComposerLayoutRoot_new" data-composer-utility-bar-variant="home"><div class="relative"><div class="relative"><div data-composer-body class="_ComposerLayoutBody_new"><textarea></textarea><button id="home-control" class="bg-surface">Model</button></div></div></div></div>
<div data-thread-scroll-footer><div id="backdrop" class="pointer-events-none absolute inset-x-0 -top-8 z-0 bottom-0 mt-8 bg-surface"></div><div class="relative z-10"><div id="thread" class="_ComposerLayoutRoot_new"><div data-composer-body><button id="thread-control" class="bg-surface">Send</button></div></div></div></div>
<div id="unrelated" class="pointer-events-none absolute z-0 bg-surface"></div>
</main><pre id="report"></pre><script>
const bg=id=>getComputedStyle(document.getElementById(id)).backgroundColor;
const body=id=>getComputedStyle(document.querySelector('#'+id+' [data-composer-body]')).backgroundColor;
document.getElementById('report').textContent=JSON.stringify({legacy:body('legacy'),modern:body('modern'),backdrop:bg('backdrop'),homeControl:bg('home-control'),threadControl:bg('thread-control'),unrelated:bg('unrelated'),fade:getComputedStyle(document.getElementById('fade')).backgroundImage,surface:bg('modern'),height:document.querySelector('#modern [data-composer-body]').getBoundingClientRect().height});
</script></body></html>`);
    const result = await dumpDOM(browser, ['--headless','--disable-gpu','--no-first-run','--disable-background-networking',`--user-data-dir=${dir}/profile`,'--dump-dom',pathToFileURL(page).href]);
    const report = JSON.parse(result.match(/<pre id="report">([^<]+)<\/pre>/)[1]);
    for (const name of ['legacy','modern','backdrop']) assert.equal(report[name], 'rgba(0, 0, 0, 0)', name);
    for (const name of ['homeControl','threadControl','unrelated']) assert.equal(report[name], 'rgb(54, 54, 54)', name);
    assert.notEqual(report.surface, 'rgba(0, 0, 0, 0)');
    assert.equal(report.height, 98);
    assert.equal(report.fade, 'none');
  } finally {await fs.rm(dir, {recursive:true,force:true});}
});

test('verification selects the active page after hidden cached home and thread pages', {skip: !hasBrowser, timeout:30000}, async () => {
  const {verifySession} = await import('../../Resources/DreamSkinRuntime/scripts/injector/renderer-verification.mjs');
  let expression;
  await verifySession({target:{id:'fixture'},evaluate:async value=>{expression=value;return {};},send:async()=>{throw new Error('Browser window not found');}});
  const dir=await fs.mkdtemp(path.join(os.tmpdir(),'dreamskin-active-page-'));
  try {
    const page=path.join(dir,'fixture.html');
    await fs.writeFile(page, `<html><style>main{width:800px;height:500px}.composer-surface-chrome{width:700px;height:98px}aside{width:200px;height:500px}</style><body>
<div style="display:none"><main data-app-shell-main-surface data-ds-part="main"><div role="main"><span data-testid="home-icon"></span></div><div class="composer-surface-chrome" data-ds-part="composer"></div></main></div>
<aside class="app-shell-left-panel"></aside><main data-app-shell-main-surface data-ds-part="main"><div class="composer-surface-chrome" data-ds-part="composer"></div></main><pre id="report"></pre><script>document.getElementById('report').textContent=JSON.stringify(${expression});</script></body></html>`);
    const result=await dumpDOM(browser,['--headless','--disable-gpu','--no-first-run','--disable-background-networking',`--user-data-dir=${dir}/profile`,'--window-size=1440,900','--dump-dom',pathToFileURL(page).href]);
    const report=JSON.parse(result.match(/<pre id="report">([^<]+)<\/pre>/)[1]);
    assert.equal(report.homeRoute,false);
    assert.equal(report.homePresent,false);
    for(const key of ['shell','composer','genericMain','genericInput'])assert.equal(report[key].visible,true,key);
  }finally{await fs.rm(dir,{recursive:true,force:true});}
});
