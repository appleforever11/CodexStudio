#!/usr/bin/env node

import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { Script } from "node:vm";

const here = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(here, "..");
const runtimeRoot = path.join(repositoryRoot, "Resources", "DreamSkinRuntime");
const expectedUpstreamVersion = "1.5.21";
const expectedInstallerSha256 = "80e6fb4d6e0b96df84d5cd324d419c1cfc97aba6e4a4b62b83b29c3f1de62c42";
const cssFiles = [
  "dream-skin.css",
  "dream-skin/tokens.css",
  "dream-skin/shell.css",
  "dream-skin/home.css",
  "dream-skin/composer.css",
  "dream-skin/task.css",
  "dream-skin/controls.css",
  "dream-skin/accessibility.css",
  "dream-skin/workspace.css",
  "dream-skin/direct-workspace.css",
  "dream-skin/dot.css",
];
const rendererFiles = [
  "renderer/bootstrap.js",
  "renderer/palette.js",
  "renderer/art-analysis.js",
  "renderer/animation.js",
  "renderer/style.js",
  "renderer/parts.js",
  "renderer/workspace-controls.js",
  "renderer/workspace-reading.js",
  "renderer/workspace-navigation.js",
  "renderer/workspace.js",
  "renderer/direct-workspace.js",
  "renderer/scope.js",
  "renderer/cleanup.js",
  "renderer/lifecycle.js",
];

function parseArguments(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (!flag?.startsWith("--") || value === undefined) {
      throw new Error(`Expected --name value, received ${flag ?? "<missing>"}`);
    }
    const key = flag.slice(2);
    if (!["upstream", "installer", "theme", "workspace", "output"].includes(key) || result[key]) {
      throw new Error(`Unknown or repeated argument: ${flag}`);
    }
    result[key] = path.resolve(value);
  }
  for (const key of ["upstream", "installer", "theme", "workspace", "output"]) {
    if (!result[key]) throw new Error(`Missing --${key}`);
  }
  return result;
}

async function sha256(file) {
  return createHash("sha256").update(await fs.readFile(file)).digest("hex");
}

async function readText(file) {
  return fs.readFile(file, "utf8");
}

async function assertRegularFile(file, label) {
  const stat = await fs.lstat(file);
  if (!stat.isFile() || stat.isSymbolicLink()) throw new Error(`${label} must be a regular file: ${file}`);
  return stat;
}

async function composeRendererAssets() {
  const assetsRoot = path.join(runtimeRoot, "assets");
  const css = (await Promise.all(cssFiles.map((file) => readText(path.join(assetsRoot, file))))).join("\n");
  const template = await readText(path.join(assetsRoot, "renderer-inject.js"));
  const rendererCode = (await Promise.all(
    rendererFiles.map((file) => readText(path.join(assetsRoot, file))),
  )).join("\n");
  const renderer = template.replace("__DREAM_SKIN_RENDERER_CODE__", () => rendererCode);
  if (renderer === template || renderer.includes("__DREAM_SKIN_RENDERER_CODE__")) {
    throw new Error("Renderer module placeholder was not composed exactly once");
  }
  return { css, renderer };
}

function patchWindowsInjector(source, rendererVersion) {
  const importNeedle = 'import { readThemeTransparency, themePreferencesPath } from "../assets/theme-preferences.mjs";';
  const workspaceImport = 'import { loadWorkspacePreferences } from "../assets/workspace-preferences.mjs";';
  if (!source.includes(importNeedle) || source.includes(workspaceImport)) {
    throw new Error("Pinned Windows injector imports no longer match the reviewed source");
  }
  let patched = source.replace(importNeedle, `${importNeedle}\n${workspaceImport}`);
  const versionNeedle = `const SKIN_VERSION = "${expectedUpstreamVersion}";`;
  if (!patched.includes(versionNeedle)) throw new Error("Pinned Windows injector version line is missing");
  patched = patched.replace(versionNeedle, `const SKIN_VERSION = "${rendererVersion}";`);
  const payloadNeedle = "  const loadedTheme = candidateTheme ?? await loadTheme(themeDir);";
  if (!patched.includes(payloadNeedle)) throw new Error("Pinned Windows payload loader no longer matches");
  patched = patched.replace(
    payloadNeedle,
    `${payloadNeedle}\n  loadedTheme.theme.workspaceUI = await loadWorkspacePreferences(themeDir);`,
  );
  if ((patched.match(/loadWorkspacePreferences\(themeDir\)/g) ?? []).length !== 1) {
    throw new Error("Workspace preferences patch was not applied exactly once");
  }
  return patched;
}

function replaceExact(source, before, after, label) {
  const count = source.split(before).length - 1;
  if (count !== 1) throw new Error(`${label} expected exactly one reviewed source match, found ${count}`);
  return source.replace(before, after);
}

function patchWindowsPowerShell(source, name) {
  const processCount = /\(Get-DreamSkinCodexProcesses -Codex ([^)]+)\)\.Count/g;
  const processMatches = source.match(processCount) ?? [];
  if (["install-dream-skin.ps1", "restore-dream-skin.ps1", "start-dream-skin.ps1"].includes(name)) {
    const expected = { "install-dream-skin.ps1": 2, "restore-dream-skin.ps1": 5, "start-dream-skin.ps1": 6 }[name];
    if (processMatches.length !== expected) {
      throw new Error(`${name} expected ${expected} strict-mode process count sites, found ${processMatches.length}`);
    }
    return source.replace(processCount, "@(Get-DreamSkinCodexProcesses -Codex $1).Count");
  }
  if (name !== "common-windows.ps1") throw new Error(`Unsupported PowerShell compatibility target: ${name}`);
  let patched = replaceExact(
    source,
    "  return (Get-DreamSkinPortListeners -Port $Port).Count -eq 0",
    "  return @(Get-DreamSkinPortListeners -Port $Port).Count -eq 0",
    "port availability count",
  );
  patched = replaceExact(
    patched,
    "  $listeners = Get-DreamSkinPortListeners -Port $Port",
    "  $listeners = @(Get-DreamSkinPortListeners -Port $Port)",
    "port listener assignment",
  );
  patched = replaceExact(
    patched,
    "  $targets = Get-DreamSkinCdpTargets -Port $Port",
    "  $targets = @(Get-DreamSkinCdpTargets -Port $Port)",
    "CDP target assignment",
  );
  patched = replaceExact(
    patched,
    "  $processes = Get-DreamSkinCodexProcessesExcept -Codex $Codex -PreserveProcessIds $PreserveProcessIds",
    "  $processes = @(Get-DreamSkinCodexProcessesExcept -Codex $Codex -PreserveProcessIds $PreserveProcessIds)",
    "process assignment",
  );
  patched = replaceExact(
    patched,
    "  $remaining = Get-DreamSkinCodexProcessesExcept -Codex $Codex -PreserveProcessIds $PreserveProcessIds",
    "  $remaining = @(Get-DreamSkinCodexProcessesExcept -Codex $Codex -PreserveProcessIds $PreserveProcessIds)",
    "remaining process assignment",
  );
  patched = patched.replace(
    /\(Get-DreamSkinCodexProcessesExcept -Codex \$Codex `\n      -PreserveProcessIds \$PreserveProcessIds\)\.Count/g,
    "@(Get-DreamSkinCodexProcessesExcept -Codex $Codex `\n      -PreserveProcessIds $PreserveProcessIds).Count",
  );
  if ((patched.match(/@\(Get-DreamSkinCodexProcessesExcept -Codex \$Codex `/g) ?? []).length !== 2) {
    throw new Error("common-windows.ps1 expected two multiline strict-mode process count patches");
  }
  return patched;
}

function normalizeTheme(raw) {
  if (!raw || raw.schemaVersion !== 1 || raw.name !== "Golden Gate" || typeof raw.image !== "string") {
    throw new Error("The selected theme is not the expected Golden Gate schema");
  }
  return {
    ...raw,
    id: "preset-macos-golden-gate-amber-bridge",
    image: "background.jpg",
    appearance: "dark",
  };
}

function validateWorkspace(raw) {
  if (!raw || raw.schemaVersion !== 1 || raw.enabled !== true) {
    throw new Error("Workspace appearance must be an enabled schemaVersion 1 object");
  }
  return raw;
}

async function writeJson(file, value) {
  await fs.writeFile(file, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const windowsRoot = path.join(options.upstream, "windows");
  const upstreamVersion = (await readText(path.join(windowsRoot, "VERSION"))).trim();
  if (upstreamVersion !== expectedUpstreamVersion) {
    throw new Error(`Expected Windows compatibility layer ${expectedUpstreamVersion}, found ${upstreamVersion}`);
  }
  const installerHash = await sha256(options.installer);
  if (installerHash !== expectedInstallerSha256) {
    throw new Error(`Pinned Windows installer SHA-256 mismatch: ${installerHash}`);
  }
  await assertRegularFile(options.installer, "Windows installer");
  await assertRegularFile(options.workspace, "Workspace preferences");
  const outputParent = path.dirname(options.output);
  await fs.mkdir(outputParent, { recursive: true });
  try {
    await fs.lstat(options.output);
    throw new Error(`Output already exists; choose a new empty path: ${options.output}`);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }

  const rendererVersion = (await readText(path.join(runtimeRoot, "VERSION"))).trim();
  if (!/^\d+\.\d+\.\d+$/.test(rendererVersion)) throw new Error("Codex Studio runtime VERSION is invalid");
  const themePath = path.join(options.theme, "theme.json");
  const theme = normalizeTheme(JSON.parse(await readText(themePath)));
  const sourceImage = path.join(options.theme, JSON.parse(await readText(themePath)).image);
  const imageStat = await assertRegularFile(sourceImage, "Golden Gate artwork");
  if (imageStat.size < 1 || imageStat.size > 10 * 1024 * 1024) {
    throw new Error("Golden Gate artwork must be between 1 byte and 10 MiB");
  }
  const workspace = validateWorkspace(JSON.parse(await readText(options.workspace)));
  const { css, renderer } = await composeRendererAssets();
  const upstreamInjector = await readText(path.join(windowsRoot, "scripts", "injector.mjs"));
  const patchedInjector = patchWindowsInjector(upstreamInjector, rendererVersion);
  const patchedPowerShell = {};
  for (const name of [
    "common-windows.ps1", "install-dream-skin.ps1", "restore-dream-skin.ps1", "start-dream-skin.ps1",
  ]) {
    patchedPowerShell[name] = patchWindowsPowerShell(
      await readText(path.join(windowsRoot, "scripts", name)), name,
    );
  }
  new Script(renderer, { filename: "renderer-inject.js" });

  const patchAssets = path.join(options.output, "patch", "assets");
  const patchScripts = path.join(options.output, "patch", "scripts");
  const themeRoot = path.join(options.output, "theme");
  await Promise.all([
    fs.mkdir(patchAssets, { recursive: true }),
    fs.mkdir(patchScripts, { recursive: true }),
    fs.mkdir(themeRoot, { recursive: true }),
  ]);
  await Promise.all([
    fs.writeFile(path.join(patchAssets, "dream-skin.css"), css, "utf8"),
    fs.writeFile(path.join(patchAssets, "renderer-inject.js"), renderer, "utf8"),
    fs.copyFile(path.join(runtimeRoot, "assets", "selectors.json"), path.join(patchAssets, "selectors.json")),
    fs.copyFile(
      path.join(runtimeRoot, "scripts", "injector", "workspace-preferences.mjs"),
      path.join(patchAssets, "workspace-preferences.mjs"),
    ),
    fs.copyFile(
      path.join(windowsRoot, "assets", "theme-preferences.mjs"),
      path.join(patchAssets, "theme-preferences.mjs"),
    ),
    fs.copyFile(
      path.join(windowsRoot, "assets", "theme-package-validator.mjs"),
      path.join(patchAssets, "theme-package-validator.mjs"),
    ),
    fs.copyFile(
      path.join(windowsRoot, "assets", "safe-css-validator.mjs"),
      path.join(patchAssets, "safe-css-validator.mjs"),
    ),
    fs.copyFile(
      path.join(windowsRoot, "scripts", "image-metadata.mjs"),
      path.join(patchScripts, "image-metadata.mjs"),
    ),
    fs.writeFile(path.join(patchScripts, "injector.mjs"), patchedInjector, "utf8"),
    ...Object.entries(patchedPowerShell).map(([name, source]) =>
      fs.writeFile(path.join(patchScripts, name), source, "utf8")),
    fs.copyFile(sourceImage, path.join(themeRoot, "background.jpg")),
    writeJson(path.join(themeRoot, "theme.json"), theme),
    writeJson(path.join(options.output, "workspace-ui.json"), workspace),
    fs.copyFile(options.installer, path.join(options.output, "CodexDreamSkin-Setup-v1.5.21.exe")),
    fs.copyFile(path.join(here, "Install-Golden-Gate.ps1"), path.join(options.output, "Install-Golden-Gate.ps1")),
    fs.copyFile(path.join(here, "Install Golden Gate.cmd"), path.join(options.output, "Install Golden Gate.cmd")),
  ]);

  const relativeFiles = [
    "CodexDreamSkin-Setup-v1.5.21.exe",
    "Install-Golden-Gate.ps1",
    "Install Golden Gate.cmd",
    "workspace-ui.json",
    "patch/assets/dream-skin.css",
    "patch/assets/renderer-inject.js",
    "patch/assets/selectors.json",
    "patch/assets/workspace-preferences.mjs",
    "patch/assets/theme-preferences.mjs",
    "patch/assets/theme-package-validator.mjs",
    "patch/assets/safe-css-validator.mjs",
    "patch/scripts/injector.mjs",
    "patch/scripts/image-metadata.mjs",
    "patch/scripts/common-windows.ps1",
    "patch/scripts/install-dream-skin.ps1",
    "patch/scripts/restore-dream-skin.ps1",
    "patch/scripts/start-dream-skin.ps1",
    "theme/background.jpg",
    "theme/theme.json",
  ];
  const files = {};
  for (const relative of relativeFiles) {
    const file = path.join(options.output, ...relative.split("/"));
    files[relative] = { bytes: (await fs.stat(file)).size, sha256: await sha256(file) };
  }
  const manifest = {
    schemaVersion: 1,
    port: "Codex Studio Golden Gate for Windows",
    rendererVersion,
    upstream: {
      repository: "https://github.com/Fei-Away/Codex-Dream-Skin",
      version: expectedUpstreamVersion,
      installerSha256: expectedInstallerSha256,
    },
    theme: { id: theme.id, name: theme.name, appearance: theme.appearance },
    files,
  };
  await writeJson(path.join(options.output, "manifest.json"), manifest);
  console.log(JSON.stringify({ output: options.output, rendererVersion, files: relativeFiles.length }, null, 2));
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
