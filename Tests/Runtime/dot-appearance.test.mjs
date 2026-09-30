import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {dumpDOM} from './support/headless-html.mjs';
const browser = process.env.DREAM_SKIN_TEST_CHROMIUM || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const available = await fs.access(browser).then(() => true, () => false);
test('Dot bubbles separate roles, clear wrappers, retain rich content and disable cleanly', {skip: !available, timeout: 30000}, async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'dot-appearance-'));
  try {
    const css = await fs.readFile(new URL('../../Resources/DreamSkinRuntime/assets/dream-skin/dot.css', import.meta.url), 'utf8');
    const html = `<!doctype html><html data-dream-skin="active" data-dream-workspace-ui="true" data-dream-dot-ui="true"><style>
      body{background:#17191e;color:white;font:16px system-ui;padding:40px}.message-list{width:800px;margin:auto}
      .message-row{display:flex;background:#302820;border:1px solid brown;margin-bottom:0}.message-row.self{justify-content:flex-end}
      .message-bubble-wrap{width:100%}.message-bubble{background:#333;width:fit-content}.message-surface{background:#302820;border:1px solid brown}
      ${css}</style><div class="messaging-root messaging-embedded"><div class="message-list">
      <div class="message-row grouped-next"><div class="message-bubble-wrap"><div class="message-body"><div class="message-surface"><div class="message-bubble assistant-bubble">Hey! I’m your dot.</div></div></div></div></div>
      <div class="message-row self"><div class="message-surface"><div class="message-bubble">Thanks! Keep me posted.</div></div></div>
      <div class="message-row assistant"><div class="message-bubble-wrap"><div class="message-surface"><div class="message-bubble"><div data-orbit-message-parts><div class="message-bubble" data-orbit-message-text-part>Here’s your update.</div><div data-orbit-message-writing-block>Native writing block</div></div></div></div></div></div>
      </div></div><div class="ordinary-chat"><div class="message-bubble">Ordinary chat</div></div><pre id="report"></pre><script>
      let checkIndex=0;const check=(v)=>{checkIndex++;if(!v)throw Error('Dot layout assertion failed '+checkIndex)};
      try {
        const dot=document.querySelector('.assistant-bubble'), mine=document.querySelector('.self .message-bubble');
        const expected=(hex)=>{const e=document.createElement('div');e.style.backgroundColor='color-mix(in srgb, '+hex+' 88%, transparent)';document.body.append(e);const c=getComputedStyle(e).backgroundColor;e.remove();return c};
        check(getComputedStyle(dot).backgroundColor===expected('#2563EB')); check(getComputedStyle(mine).backgroundColor===expected('#4B5563'));
        const host=document.querySelector('.messaging-root');check(getComputedStyle(host).backgroundImage.includes('radial-gradient'));
        check(getComputedStyle(dot).backdropFilter.includes('18px'));
        check(getComputedStyle(dot.closest('.message-row')).marginBottom==='14px');
        check(dot.closest('.message-bubble-wrap').getBoundingClientRect().width<680);
        check(getComputedStyle(dot.closest('.message-surface')).backgroundColor==='rgba(0, 0, 0, 0)');
        check(getComputedStyle(document.querySelector('[data-orbit-message-text-part]')).backgroundColor===expected('#2563EB'));
        check(getComputedStyle(document.querySelector('[data-orbit-message-parts]').parentElement).backgroundColor==='rgba(0, 0, 0, 0)');
        check(getComputedStyle(document.querySelector('.ordinary-chat .message-bubble')).backgroundColor==='rgb(51, 51, 51)');
        document.documentElement.dataset.dreamDotUi='false';check(getComputedStyle(dot).backgroundColor==='rgb(51, 51, 51)');
        document.getElementById('report').textContent=JSON.stringify({pass:true});
      }catch(e){document.getElementById('report').textContent=JSON.stringify({error:e.message})}
      </script>`;
    const file=path.join(root,'dot.html'); await fs.writeFile(file,html);
    const output=await dumpDOM(browser,['--headless','--disable-gpu','--no-first-run','--no-default-browser-check',`--user-data-dir=${root}/profile`,'--window-size=1200,900','--dump-dom',pathToFileURL(file).href]);
    const report=output.match(/<pre id="report">([^<]+)<\/pre>/)?.[1];
    assert.ok(report); assert.deepEqual(JSON.parse(report),{pass:true});
  } finally { await fs.rm(root,{recursive:true,force:true}); }
});
