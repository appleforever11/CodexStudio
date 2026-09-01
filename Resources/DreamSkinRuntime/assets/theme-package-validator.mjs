#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import {
  parseArguments,
  resolveDirectory,
  sourceFileNames,
} from "./theme-package-primitives.mjs";
import {
  validateOfficial,
  validateSimple,
} from "./theme-package-files.mjs";

export {
  codePointLength,
  normalizeThemeText,
  normalizeThemeColor,
} from "./theme-package-primitives.mjs";

export async function main() {
  const args = parseArguments(process.argv.slice(2));
  const source = await resolveDirectory(args.source, "Theme package source");
  const stage = await resolveDirectory(args.stage, "Theme package stage", true);
  const names = await sourceFileNames(source);
  const result = names.includes("manifest.json")
    ? await validateOfficial(source, names, args.platform, args["client-version"])
    : await validateSimple(source, names);
  for (const [name, bytes] of result.bytes) {
    await fs.writeFile(path.join(stage, name), bytes, { flag: "wx", mode: 0o600 });
    await fs.chmod(path.join(stage, name), 0o600);
  }
  return {
    format: result.format,
    image: result.image,
    safeCssStatus: result.safeCssStatus,
    signatureIgnored: result.signatureIgnored,
  };
}

if (path.resolve(process.argv[1] || "") === path.resolve(fileURLToPath(import.meta.url))) {
  try {
    process.stdout.write(`${JSON.stringify(await main())}\n`);
  } catch (error) {
    process.stderr.write(`Theme package validation failed: ${error?.message ?? error}\n`);
    process.exitCode = 1;
  }
}
