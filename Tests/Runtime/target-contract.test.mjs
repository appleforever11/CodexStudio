import test from "node:test";
import assert from "node:assert/strict";
import { classifyCodexTarget, summarizeCodexTargets } from "../../Resources/DreamSkinRuntime/scripts/injector/target-contract.mjs";

test("classifies Codex renderer targets without crossing webview boundaries", () => {
  assert.equal(classifyCodexTarget({ type: "page", url: "app://-/index.html" }), "codex-page");
  assert.equal(classifyCodexTarget({ type: "page", url: "app://-/index.html?initialRoute=%2Favatar-overlay" }), "excluded-surface");
  assert.equal(classifyCodexTarget({ type: "webview", url: "https://chatgpt.com" }), "webview");
  assert.equal(classifyCodexTarget({ type: "page", url: "https://example.com" }), "external-page");
});

test("summarizes mixed DevTools targets", () => {
  assert.deepEqual(summarizeCodexTargets([
    { type: "page", url: "app://-/index.html" },
    { type: "page", url: "app://-/index.html?initialRoute=%2Favatar-overlay" },
    { type: "webview", url: "https://chatgpt.com" },
  ]), {
    total: 3,
    "codex-page": 1,
    "excluded-surface": 1,
    webview: 1,
    "external-page": 0,
    unsupported: 0,
  });
});
