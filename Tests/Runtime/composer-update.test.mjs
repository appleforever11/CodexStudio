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
._fade_106nk_2,._combined_106nk_2 {height:32px;background-image:linear-gradient(to top,black,transparent)}
[data-composer-body],.bg-surface {background:rgb(54,54,54)}
[data-composer-body]{height:98px}[data-thread-scroll-footer]{position:relative;height:114px}
</style><style>${css}</style><body><main data-app-shell-main-surface="default"><div class="group/thread-scroll-layout"><div id="module-fade" aria-hidden="true" class="_background_106nk_2 _fade_106nk_2 pointer-events-none absolute inset-x-0 z-0 from-surface"></div><div id="module-combined" aria-hidden="true" class="_background_106nk_2 _combined_106nk_2 pointer-events-none absolute inset-x-0 z-0 bottom-0 from-surface"></div></div><div id="outside-module" aria-hidden="true" class="_background_106nk_2 _fade_106nk_2 pointer-events-none absolute z-0 from-surface"></div><div class="thread-scroll-container"><div class="pointer-events-none sticky bottom-0"><div id="fade" class="pointer-events-none absolute z-0 bg-gradient-to-t from-surface" style="background-image:linear-gradient(black,transparent)"></div></div></div>
<div id="legacy" class="_ComposerLayoutRoot_old" data-composer-utility-bar-variant="home"><div data-composer-body class="_ComposerLayoutBody_old"></div></div>
<div id="modern" class="_ComposerLayoutRoot_new" data-composer-utility-bar-variant="home"><div class="relative"><div class="relative"><div data-composer-body class="_ComposerLayoutBody_new"><textarea></textarea><button id="home-control" class="bg-surface">Model</button></div></div></div></div>
<div data-thread-scroll-footer><div id="backdrop" class="pointer-events-none absolute inset-x-0 -top-8 z-0 bottom-0 mt-8 bg-surface"></div><div class="relative z-10"><div id="thread" class="_ComposerLayoutRoot_new"><div data-composer-body><button id="thread-control" class="bg-surface">Send</button></div></div></div></div>
<div id="unrelated" class="pointer-events-none absolute z-0 bg-surface"></div>
</main><pre id="report"></pre><script>
const bg=id=>getComputedStyle(document.getElementById(id)).backgroundColor;
const body=id=>getComputedStyle(document.querySelector('#'+id+' [data-composer-body]')).backgroundColor;
document.getElementById('report').textContent=JSON.stringify({legacy:body('legacy'),modern:body('modern'),backdrop:bg('backdrop'),homeControl:bg('home-control'),threadControl:bg('thread-control'),unrelated:bg('unrelated'),fade:getComputedStyle(document.getElementById('fade')).backgroundImage,moduleFade:getComputedStyle(document.getElementById("module-fade")).backgroundImage,moduleCombined:getComputedStyle(document.getElementById("module-combined")).backgroundImage,outsideModule:getComputedStyle(document.getElementById("outside-module")).backgroundImage,moduleHeight:document.getElementById("module-fade").getBoundingClientRect().height,surface:bg('modern'),height:document.querySelector('#modern [data-composer-body]').getBoundingClientRect().height});
</script></body></html>`);
    const result = await dumpDOM(browser, ['--headless','--disable-gpu','--no-first-run','--disable-background-networking',`--user-data-dir=${dir}/profile`,'--dump-dom',pathToFileURL(page).href]);
    const report = JSON.parse(result.match(/<pre id="report">([^<]+)<\/pre>/)[1]);
    for (const name of ['legacy','modern','backdrop']) assert.equal(report[name], 'rgba(0, 0, 0, 0)', name);
    for (const name of ['homeControl','threadControl','unrelated']) assert.equal(report[name], 'rgb(54, 54, 54)', name);
    assert.notEqual(report.surface, 'rgba(0, 0, 0, 0)');
    assert.equal(report.height, 98);
    assert.equal(report.fade, 'none');
    assert.equal(report.moduleFade, 'none');
    assert.equal(report.moduleCombined, 'none');
    assert.notEqual(report.outsideModule, 'none');
    assert.equal(report.moduleHeight, 32);
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

test('Home rail keeps a narrow project pill reachable and native mode labels visible', {skip: !hasBrowser, timeout:30000}, async () => {
  const dir=await fs.mkdtemp(path.join(os.tmpdir(),'dreamskin-home-rail-'));
  try {
    const accessibility=await fs.readFile(new URL('../../Resources/DreamSkinRuntime/assets/dream-skin/accessibility.css',import.meta.url),'utf8');
    const page=path.join(dir,'fixture.html');
    await fs.writeFile(page, `<html data-dream-skin="active"><style>
body{font:16px system-ui} [data-codex-composer-root]{width:280px}
[data-composer-rail-item]{background:#333;border-radius:0}
[data-composer-utility-bar-scroll-area]{overflow-x:auto;margin-inline:-8px;mask-image:linear-gradient(to right,transparent,black 10%);white-space:nowrap}
button{font:inherit}#project{width:400px;height:32px;border:1px solid orange}
</style><style>${css}\n${accessibility}</style><body>
<aside class="app-shell-left-panel"><button id="mode" aria-label="Switch mode, current mode: ChatGPT"><span class="truncate">ChatGPT</span></button></aside>
<div data-codex-composer-root data-composer-placement="home"><div id="rail" data-composer-rail-item data-composer-rail-placement="above"><div id="scroll" data-composer-utility-bar-scroll-area><button id="project">A long project name that needs horizontal scrolling</button></div></div></div>
<pre id="report"></pre><script>
const style=id=>getComputedStyle(document.getElementById(id));
const scroll=document.getElementById('scroll');scroll.scrollLeft=100;
const rail=document.getElementById('rail').getBoundingClientRect(),pill=document.getElementById('project').getBoundingClientRect();
document.getElementById('report').textContent=JSON.stringify({radius:style('rail').borderRadius,overflow:style('rail').overflowX,background:style('rail').backgroundColor,mask:style('scroll').maskImage,margin:style('scroll').marginLeft,scroll:scroll.scrollLeft,topClearance:pill.top-rail.top,bottomClearance:rail.bottom-pill.bottom,label:getComputedStyle(document.querySelector('#mode span')).display,font:style('mode').fontSize,generated:getComputedStyle(document.getElementById('mode'),'::before').content});
</script></body></html>`);
    const result=await dumpDOM(browser,['--headless','--disable-gpu','--no-first-run','--disable-background-networking',`--user-data-dir=${dir}/profile`,'--dump-dom',pathToFileURL(page).href]);
    const report=JSON.parse(result.match(/<pre id="report">([^<]+)<\/pre>/)[1]);
    assert.equal(report.radius,'16px');
    assert.equal(report.overflow,'clip');
    assert.equal(report.background,'rgba(0, 0, 0, 0)');
    assert.equal(report.mask,'none');
    assert.equal(report.margin,'0px');
    assert.ok(report.scroll>0);
    assert.ok(report.topClearance>=3 && report.bottomClearance>=3);
    assert.notEqual(report.label,'none');
    assert.notEqual(report.font,'0px');
    assert.equal(report.generated,'none');
  }finally{await fs.rm(dir,{recursive:true,force:true});}
});
