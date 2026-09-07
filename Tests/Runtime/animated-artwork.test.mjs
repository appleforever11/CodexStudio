import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source = fs.readFileSync(new URL('../../Resources/DreamSkinRuntime/assets/renderer/animation.js', import.meta.url), 'utf8');
test('animated artwork freezes for reduced motion and hidden documents, then cleans listeners', () => {
  let value;
  const handlers = new Map();
  const query = { matches: false, addEventListener: (key, fn) => handlers.set('motion', fn), removeEventListener: () => handlers.delete('motion') };
  const document = { hidden: false, documentElement: {},
    addEventListener: (key, fn) => handlers.set(key, fn), removeEventListener: key => handlers.delete(key),
    createElement: () => ({ getContext: () => ({drawImage(){}}), toDataURL: () => 'data:image/png;still' }) };
  class Image { naturalWidth = 960; naturalHeight = 540; set src(value) {this.onload();} removeAttribute() {} }
  const context = { THEME: {animatedArtwork:true}, artUrl:'blob:animated', document, Image, matchMedia:()=>query,
    setStyleProperty: (root,key,next) => {value=next;} };
  vm.runInNewContext(source+';globalThis.controls={syncArtworkAnimation,disposeArtworkAnimation};',context);
  assert.equal(value,'url("blob:animated")');
  query.matches = true; handlers.get('motion')(); assert.equal(value,'url("data:image/png;still")');
  query.matches = false; document.hidden = true; handlers.get('visibilitychange')(); assert.equal(value,'url("data:image/png;still")');
  document.hidden = false; handlers.get('visibilitychange')(); assert.equal(value,'url("blob:animated")');
  context.controls.disposeArtworkAnimation(); assert.equal(handlers.size,0);
});
