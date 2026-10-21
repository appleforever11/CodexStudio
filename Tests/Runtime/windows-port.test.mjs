import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(here, "..", "..");
const buildScript = path.join(repositoryRoot, "WindowsPort", "build-golden-gate-port.mjs");
const installScript = path.join(repositoryRoot, "WindowsPort", "Install-Golden-Gate.ps1");
const cmdLauncher = path.join(repositoryRoot, "WindowsPort", "Install Golden Gate.cmd");

test("Windows port recipe pins reversible Store-package compatibility inputs", async () => {
  const [builder, installer, launcher] = await Promise.all([
    fs.readFile(buildScript, "utf8"),
    fs.readFile(installScript, "utf8"),
    fs.readFile(cmdLauncher, "utf8"),
  ]);
  assert.match(builder, /expectedUpstreamVersion = "1\.5\.21"/);
  assert.match(builder, /80e6fb4d6e0b96df84d5cd324d419c1cfc97aba6e4a4b62b83b29c3f1de62c42/);
  assert.match(builder, /loadWorkspacePreferences\(themeDir\)/);
  assert.match(builder, /patchAssets, "theme-preferences\.mjs"/);
  assert.match(builder, /patchScripts, "image-metadata\.mjs"/);
  assert.match(builder, /patchWindowsPowerShell/);
  assert.match(builder, /return @\(Get-DreamSkinPortListeners -Port \$Port\)\.Count/);
  assert.match(builder, /\$targets = @\(Get-DreamSkinCdpTargets -Port \$Port\)/);
  assert.match(installer, /Get-AppxPackage -Name \$expectedPackageName/);
  assert.match(installer, /PublisherId\)" -cne '2p2nqsd0c76g0'/);
  assert.match(installer, /golden-gate-backups/);
  assert.match(installer, /System\.Security\.Cryptography\.SHA256/);
  assert.doesNotMatch(installer, /Get-FileHash/);
  assert.match(installer, /start-dream-skin\.ps1.*-RestartExisting/s);
  assert.match(installer, /verify-dream-skin\.ps1/);
  assert.match(installer, /scripts\\common-windows\.ps1/);
  assert.doesNotMatch(installer, /WindowsApps.*(?:Copy-Item|Remove-Item|Set-Acl)/s);
  assert.match(launcher, /Install-Golden-Gate\.ps1/);
});

test("Windows port composes the complete current renderer module order", async () => {
  const builder = await fs.readFile(buildScript, "utf8");
  for (const module of [
    "renderer/bootstrap.js",
    "renderer/workspace-controls.js",
    "renderer/workspace-reading.js",
    "renderer/direct-workspace.js",
    "renderer/lifecycle.js",
  ]) assert.ok(builder.includes(`"${module}"`), `missing ${module}`);
  for (const stylesheet of [
    "dream-skin/tokens.css",
    "dream-skin/composer.css",
    "dream-skin/workspace.css",
    "dream-skin/direct-workspace.css",
    "dream-skin/dot.css",
  ]) assert.ok(builder.includes(`"${stylesheet}"`), `missing ${stylesheet}`);
});
