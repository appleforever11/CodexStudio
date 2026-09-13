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

test("active task threads retain a stable surface during native swaps", () => {
  assert.match(taskCss, /:has\(button\[aria-label="Stop"\]\)/);
  assert.match(taskCss, /background: rgb\(var\(--ds-bg-rgb\) \/ \.94\) !important;/);
  assert.match(taskCss, /:not\(:has\(\.thread-scroll-container\)\)/);
  assert.match(taskCss, /::before \{\n  content: none !important;/);
});

test("streaming DOM changes defer parts reconciliation to idle time", () => {
  assert.match(lifecycle, /const PART_RECONCILE_TIMEOUT = 250;/);
  assert.match(lifecycle, /window\.requestIdleCallback\(flush/);
  assert.match(lifecycle, /timeout: PART_RECONCILE_TIMEOUT/);
  assert.match(lifecycle, /cancelPartReconcile/);
});
