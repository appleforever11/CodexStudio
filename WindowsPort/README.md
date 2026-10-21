# Golden Gate Windows port

This directory builds a local-only Windows transfer bundle that combines:

- the reviewed Windows launch, loopback-CDP, restore and verification layer from
  Codex Dream Skin v1.5.21;
- Codex Studio's current modular renderer and selectors;
- the active local Golden Gate theme and workspace appearance settings.

The generated bundle does not patch `WindowsApps`, replace `app.asar`, take file
ownership, or redistribute the Golden Gate wallpaper through Git. It installs
the upstream reversible engine under `%LOCALAPPDATA%\CodexDreamSkin`, replaces
only that managed engine's renderer assets, stages Golden Gate as the active and
saved theme, then starts Codex through the upstream verified Store-package/CDP
path. The original Codex appearance remains recoverable from the installed
`Codex Dream Skin - Restore` shortcut.

## Build

Use Node 22 or newer:

```sh
node WindowsPort/build-golden-gate-port.mjs \
  --upstream /path/to/Codex-Dream-Skin \
  --installer /path/to/CodexDreamSkin-Setup-v1.5.21.exe \
  --theme "$HOME/Library/Application Support/CodexDreamSkinStudio/theme" \
  --workspace "$HOME/Library/Application Support/CodexDreamSkinStudio/workspace-ui.json" \
  --output WindowsPort/output/GoldenGateWindowsPort
```

The builder refuses an existing output directory, verifies the pinned upstream
version and installer SHA-256, composes the same ordered CSS and renderer modules
used by macOS, validates every generated file, and writes `manifest.json`.

## Apply on Windows

Copy the generated folder to Windows and double-click
`Install Golden Gate.cmd`. The launcher asks for confirmation because the
official Codex window must close briefly. The PowerShell installer validates all
bundle hashes and the exact `OpenAI.Codex` Store identity, runs the pinned
upstream installer, retains timestamped backups, stages the theme, and relaunches
Codex through the managed loopback profile.

`install-result.json` records the installed renderer version, theme identity,
and verification result. A successful script result proves installation and
renderer checks; a visual match still requires inspecting the rebuilt Codex
window on the Windows display.

The launcher uses a process-only PowerShell execution-policy override because
the local script is not Authenticode-signed. It does not change the user or
machine execution policy, and the script validates every staged input against
the bundle manifest before closing Codex or installing anything.

## Sources and boundaries

- Windows compatibility layer: <https://github.com/Fei-Away/Codex-Dream-Skin/tree/v1.5.21/windows>
- Upstream installer SHA-256:
  `80e6fb4d6e0b96df84d5cd324d419c1cfc97aba6e4a4b62b83b29c3f1de62c42`
- The generated bundle is for this local migration and is not a public release.
