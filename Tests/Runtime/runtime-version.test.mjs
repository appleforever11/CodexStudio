import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../Resources/DreamSkinRuntime");

test("injector and VERSION use one runtime version", async () => {
  const version = (await fs.readFile(path.join(root, "VERSION"), "utf8")).trim();
  const config = await import("../../Resources/DreamSkinRuntime/scripts/injector/config.mjs");
  const facade = await import("../../Resources/DreamSkinRuntime/scripts/injector.mjs");
  assert.match(version, /^\d+\.\d+\.\d+$/);
  assert.equal(config.runtimeVersion, version);
  assert.equal(facade.SKIN_VERSION, version);
});
