import fs from 'node:fs/promises';
import path from 'node:path';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const run = promisify(execFile);
export const revealBinding = '__dreamSkinRevealOutput';

export async function revealOutput(session, payload, execute = run) {
  if (typeof payload !== 'string' || payload.length > 8192) return false;
  let request; try { request = JSON.parse(payload); } catch { return false; }
  const file = request?.path;
  if (typeof file !== 'string' || file.length > 4096 || file.includes('\0') || !path.isAbsolute(file)) return false;
  // Only reveal a file already displayed by a native Outputs row. Never accept
  // arbitrary commands, shell fragments, URLs, or paths supplied by chat text.
  const allowed = await session.evaluate(`(()=>{
    if(location.protocol!=='app:' || location.host!=='-' || document.documentElement.getAttribute('data-dream-skin')!=='active')return false;
    return [...document.querySelectorAll('[data-summary-panel-variant] section')]
      .filter(s=>s.querySelector('header')?.textContent.trim()==='Outputs')
      .some(s=>[...s.querySelectorAll('[data-slot="thread-summary-panel-item-button"][title]')]
      .some(e=>e.getAttribute('title')===${JSON.stringify(file)}));
  })()`);
  if (!allowed) return false;
  const info = await fs.stat(file).catch(()=>null);
  if (!info?.isFile()) return false;
  await execute('/usr/bin/open', ['-R', file], {timeout:5000,maxBuffer:8192});
  return true;
}
export async function installOutputActions(session) {
  if (process.platform !== 'darwin') return;
  let busy = false, last = 0;
  session.on('Runtime.bindingCalled', event => {
    if(event.name !== revealBinding || busy || Date.now()-last<500)return;
    busy=true;last=Date.now();
    revealOutput(session,event.payload).catch(()=>false).then(async ok=>{
      let file;try{file=JSON.parse(event.payload)?.path;}catch{return;}
      if(typeof file!=='string'||file.length>4096)return;
      await session.evaluate(`document.dispatchEvent(new CustomEvent('dream-skin-reveal-result',{detail:${JSON.stringify({path:file,ok})}}))`).catch(()=>{});
    }).finally(()=>{busy=false;});
  });
  await session.send('Runtime.addBinding',{name:revealBinding});
  await session.evaluate("document.dispatchEvent(new Event('dream-skin-output-ready'))");
}
