import { acquireLock, resolveRealDirectory } from "./import-theme/lock.mjs";
import { recoverReplacementTransactions } from "./import-theme/recovery.mjs";
import { runImport } from "./import-theme/publisher.mjs";

const cliArgs = process.argv.slice(2);
const recoveryOnly = cliArgs[0] === "--recover";
const stageDirArg = recoveryOnly ? null : cliArgs[0];
const themesRootArg = cliArgs[1];
if (!themesRootArg || (!recoveryOnly && !stageDirArg) || cliArgs.length !== 2) {
  throw new Error(
    "Usage: publish-theme-import.mjs <validated-stage-dir> <saved-themes-root> | --recover <saved-themes-root>",
  );
}

const themesRoot = await resolveRealDirectory(themesRootArg, "Saved themes root");
let result;
if (recoveryOnly) {
  const releaseLock = await acquireLock(themesRoot);
  try {
    result = {
      status: "recovered",
      recovered: await recoverReplacementTransactions(themesRoot),
    };
  } finally {
    await releaseLock();
  }
} else {
  const stageRoot = await resolveRealDirectory(stageDirArg, "Theme import stage");
  result = await runImport(stageRoot, themesRoot);
}

process.stdout.write(`${JSON.stringify(result)}\n`);
