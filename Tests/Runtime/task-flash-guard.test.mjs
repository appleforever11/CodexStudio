import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";

const taskCss = await fs.readFile(
  new URL("../../Resources/DreamSkinRuntime/assets/dream-skin/task.css", import.meta.url),
  "utf8",
);
const lifecycle = await fs.readFile(
  new URL("../../Resources/DreamSkinRuntime/assets/renderer/lifecycle.js", import.meta.url),
  "utf8",
);

test("active task hosts remain paintable without replacing the themed backdrop", () => {
  assert.match(taskCss, /:has\(button\[aria-label="Stop"\]\)/);
  assert.match(taskCss, /\[class\*="content-visibility:auto"\]/);
  assert.match(taskCss, /content-visibility: visible !important;/);
  assert.match(taskCss, /contain: none !important;/);
  assert.match(taskCss, /contain-intrinsic-size: none !important;/);
  assert.doesNotMatch(taskCss, /background: rgb\(var\(--ds-bg-rgb\) \/ \.94\) !important;/);
});

test("streaming DOM changes defer parts reconciliation to idle time", () => {
  assert.match(lifecycle, /const PART_RECONCILE_TIMEOUT = 250;/);
  assert.match(lifecycle, /window\.requestIdleCallback\(flush/);
  assert.match(lifecycle, /timeout: PART_RECONCILE_TIMEOUT/);
  assert.match(lifecycle, /cancelPartReconcile/);
});
