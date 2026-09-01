import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const modulePath = fileURLToPath(import.meta.url);
const moduleDirectory = path.dirname(modulePath);

export const runtimeRoot = path.resolve(moduleDirectory, "../..");
export const assetsRoot = path.join(runtimeRoot, "assets");
export const runtimeVersion = "1.6.0";

const selectorContract = JSON.parse(await fs.readFile(
  path.join(assetsRoot, "selectors.json"),
  "utf8",
));
if (selectorContract.schema !== "codex-dream-skin-selectors/1"
  || !Array.isArray(selectorContract.selectors)) {
  throw new Error("assets/selectors.json has an unsupported schema");
}

const selectorMap = new Map();
for (const entry of selectorContract.selectors) {
  if (!entry?.key || !entry.selector || selectorMap.has(entry.key)) {
    throw new Error(
      `assets/selectors.json has an invalid selector key: ${entry?.key || "<missing>"}`,
    );
  }
  selectorMap.set(entry.key, entry.selector);
}

export const selectorFor = (key) => {
  const selector = selectorMap.get(key);
  if (!selector) throw new Error(`Selector contract is missing ${key}`);
  return selector;
};

export const selectorLiteral = (key) => JSON.stringify(selectorFor(key));

export const stableTestidLiteral = (testid) => {
  if (!selectorContract.stableTestids?.includes(testid)) {
    throw new Error(`Selector contract is missing stable testid ${testid}`);
  }
  return JSON.stringify(`[data-testid="${testid}"]`);
};

export const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]"]);
export const CDP_ID_PATTERN = /^[A-Za-z0-9._-]{1,200}$/;
export const MAX_ART_BYTES = 10 * 1024 * 1024;
export const MAX_SAFE_CSS_BYTES = 256 * 1024;
export const OPERATION_UI_HOST_ID = "chatgpt-dream-skin-operation";
export const OPERATION_UI_REGISTRY_KEY = "__CHATGPT_DREAM_SKIN_OPERATION_UI__";
export const OPERATION_KINDS = new Set(["apply", "pause", "switch"]);
export const OPERATION_UI_STATES = new Set(["success", "error", "cancelled"]);
export const MIN_RENDERER_WIDTH = 320;
export const MIN_RENDERER_HEIGHT = 240;
export const MAX_RENDERER_DIMENSION = 65536;
