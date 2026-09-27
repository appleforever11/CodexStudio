import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { dumpDOM } from './support/headless-html.mjs';

// Real layout checks need Chromium; override this path on non-macOS hosts.
const browser = process.env.DREAM_SKIN_TEST_CHROMIUM
  || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const hasBrowser = await fs.access(browser).then(() => true, () => false);
const runtime = new URL('../../Resources/DreamSkinRuntime/assets/', import.meta.url);
const modules = ['tokens', 'shell', 'home', 'controls', 'composer', 'task', 'accessibility'];
const css = (await Promise.all(modules.map(name =>
  fs.readFile(new URL(`dream-skin/${name}.css`, runtime), 'utf8')))).join('\n');
const fixture = await fs.readFile(new URL('./fixtures/viewport-scroll.html', import.meta.url), 'utf8');

for (const [width, height] of [[1440, 900], [800, 600]]) {
  test(`outer viewport stays fixed while nested panes scroll at ${width}x${height}`, {
    skip: !hasBrowser && 'Set DREAM_SKIN_TEST_CHROMIUM to run real browser layout checks',
    timeout: 30000,
  }, async () => {
    const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'dreamskin-viewport-'));
    try {
      const page = path.join(directory, 'fixture.html');
      await fs.writeFile(page, fixture.replace('<!-- RUNTIME_CSS -->', `<style>${css}</style>`));
      const result = await dumpDOM(browser, [
        '--headless', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
        '--disable-background-networking', `--user-data-dir=${directory}/profile`,
        `--window-size=${width},${height}`, '--dump-dom', pathToFileURL(page).href,
      ]);
      const report = result.match(/<pre id="report">([^<]+)<\/pre>/)?.[1];
      assert.ok(report, 'Browser must execute the layout fixture');
      const data = JSON.parse(report);
      assert.equal(data.control.bodyTop, 60, 'Old hidden-overflow behavior reproduces the strip');
      assert.equal(data.control.shellTop, -60);
      for (const name of ['recovered', 'directScroll', 'composerFocus', 'sidebarFocus']) {
        const state = data[name];
        assert.equal(state.bodyTop, 0, `${name}: body must not scroll`);
        assert.equal(state.documentTop, 0, `${name}: document must not scroll`);
        assert.equal(state.shellTop, 0, `${name}: shell must stay below titlebar`);
        assert.equal(state.height - state.shellBottom, 4, `${name}: retain only native window inset`);
      }
      assert.ok(data.composerFocus.threadTop > 0, 'Composer focus scrolls its conversation');
      assert.ok(data.sidebarFocus.sidebarTop > 0, 'Sidebar focus scrolls its list');
      assert.equal(data.threadDown, 300);
      assert.equal(data.threadUp, 100);
      assert.equal(data.sidebarDown, 200);
      assert.equal(data.sidebarUp, 50);
    } finally {
      await fs.rm(directory, { recursive: true, force: true });
    }
  });
}
