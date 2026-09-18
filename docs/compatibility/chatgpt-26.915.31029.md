# ChatGPT 26.915.31029 local compatibility review

Inspected September 17, 2026. Current installation: `/Applications/ChatGPT.app`,
bundle ID `com.openai.codex`, version **26.915.31029**, build **9771**.

## Comparison boundary

The September 13 deployment handoff records ChatGPT **26.908.40834** when
runtime 1.9.5 was installed and Studio was reopened. This historical record is
the last known host version for that build; its old app bundle is unavailable.
The earlier September 10 capability check recorded **26.903.71938 (8576)**,
CLI 0.153.4, and Node v24.20.0. CLI/Node versions were not captured September 13.

No corresponding September baseline app archive was found in the inspected
Sparkle cache, installed application locations, or Spotlight app.asar results.
A full old/new binary or source diff is consequently unavailable. The current
asset manifest records paths, byte sizes, and SHA-256 digests of 15,022 packed
ASAR files; it excludes unpacked/native components and is not a full app backup.
See [current manifest](chatgpt-26.915.31029-assets.json).

## Recorded and current metadata comparison

| Component | September 10 recorded baseline | Current local installation |
| --- | --- | --- |
| ChatGPT (September 10) | 26.903.71938 (8576) | 26.915.31029 (9771) |
| ChatGPT (September 13) | 26.908.40834 (build not recorded) | 26.915.31029 (9771) |
| Bundled Codex CLI | 0.153.4 | 0.155.0-alpha.9 |
| Bundled Node | v24.20.0 | v24.21.0 |

Current CLI and Node versions were read directly from the bundled executables
with `--version`.
These are verified metadata differences, not a feature-by-feature release diff.

## Welcome-heading compatibility finding

The current `webview/assets/app-primary-9cc592e777fd.js` constructs the
`data-feature="game-source"` heading with native `justify-center text-center`
and a direct `span.group/title` child. The project button is an inline-block
inside the invitation sentence, with normal whitespace and word wrapping.

Existing DreamSkin home.css overrides the heading to `text-align: inherit`
and injects a project-prefix pseudo-element into every hero button. The supplied
screenshot shows that extra "Choose project" prefix and left-aligned heading.
This is direct evidence of a theme/native style conflict, but without the old
bundle it does not establish which release first introduced the markup.

Runtime 1.9.7 includes a rule scoped to this direct group/title shape: center the
heading, remove the generated button prefix, and constrain/wrap the inline
button including long unbroken project names. Older heading shapes retain
existing rules. No native application assets were edited.

## Validation and remaining work

- All 12 Node runtime tests passed; 40 Swift tests ran with two optional network checks skipped and no failures.
- An [isolated browser fixture](home-heading-fixture.html) using the current heading shape passed at 1000px
  and 360px container widths, including a long unbroken project name.
  Computed text alignment was center, button ::before content was none,
  and heading scrollWidth equaled clientWidth in all three cases.
- Computer Use explicitly denied access to `com.openai.codex`. No alternate
  access path was used to inspect or manipulate the denied live UI.
- The final Studio 0.1.21 candidate deployed runtime 1.9.7 through its normal
  library load and Apply source theme controls. Runtime state and Connection
  diagnostics agree on 1.9.7; Golden Gate is active and ChatGPT was not restarted.
- Fixed older-watcher reuse during upgrades and retained local-only cached
  wallpaper discovery. Staged Studio shows all 704 themes and four favorites.
- A direct live welcome-screen/project-picker visual check remains unavailable
  because Computer Use denies the host app; fixture evidence is not a screenshot
  of the live ChatGPT page.
