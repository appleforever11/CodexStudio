import path from "node:path";
import { fileURLToPath } from "node:url";
import { runCli } from "./injector/cli.mjs";

const scriptPath = fileURLToPath(import.meta.url);
const SKIN_VERSION = "1.6.0";
// Keep this literal export in the executable facade for the release workflow's
// version-consistency check. The implementation modules consume the same
// runtime version from injector/config.mjs.
export { SKIN_VERSION };

export {
  assertPayloadIntegrity,
  earlyPayloadFor,
  invalidateStaticPayloadAssets,
  loadPayload,
  loadTheme,
} from "./injector/theme-payload.mjs";
export {
  assessRendererVerification,
  classifyNativeWindowError,
  classifyNativeWindowResponse,
  cleanupExcludedSurface,
  inspectNativeWindow,
  verifySession,
  waitForVerifiedSession,
} from "./injector/renderer-verification.mjs";

if (path.resolve(process.argv[1] || "") === path.resolve(scriptPath)) {
  try {
    await runCli(process.argv.slice(2));
  } catch (error) {
    console.error(`[dream-skin] ${error.stack || error.message}`);
    process.exitCode = 1;
  }
}
