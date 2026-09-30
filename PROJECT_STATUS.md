# Codex Studio handoff

## 2026-09-30 — Dot wallpaper and glass redesign, local

Replaced the native messaging host's opaque fill with active-theme artwork,
a dimmed navy veil, blue ambient glow and a subtle wallpaper-accent glow.
Cleared workspace/viewport/scroll backing without changing native geometry.
Text bubbles now have translucent blue/grey gradients, blur, edge highlights
and deeper shadows; the native composer has a matching glass surface.
Extracted the Dot rules into dream-skin/dot.css and added it to payload loading.
Corrected incoming role selection: Dot messages can lack the assistant class,
so both ordinary incoming and assistant rows now receive the blue treatment.
Images, writing blocks and Page previews retain their native content surfaces.

Studio now exposes Wallpaper dimming and Glass softness. Preview paints the
selected artwork in a finite clipped host with a sample glass composer.
Older appearance files get defaults of 32% dimming / 18px blur. New Swift view
is 111 lines. No library, theme, favorite or native app installation changes.

Rebuilt /tmp/codexstudio-dot-redesign/CodexStudio.app, debug 0.1.0 / 1000000,
review identifier; strict ad-hoc signature passes. Native Your dot preview
visually inspected; wallpaper, both bubble styles, composer and sidebar fit.
Dimming increment verified at 33%, then restored and confirmed at 32%.
Lower-control scrolling again encountered noWindowsAvailable; prior Apply/Undo
UI limitation remains. Actual Dot page visual inspection remains blocked by
computer-use app policy. User screenshot is pre-redesign evidence only.

Five runtime files hot-applied with backup at
~/Library/Application Support/CodexDreamSkinStudio/runtime-backups/before-dot-redesign-20260930-102434;
new-files.txt records dot.css as newly created. Source, installed runtime and
review-bundle files match. Refresh entrypoint passes; active watcher 57878.
ChatGPT PID 6029 stayed unchanged. One-shot renderer verification passes,
including visible composer and zero document overflow. Installed runtime stays
1.9.23 plus local patch; no app restart, release or publication.

Validation: Swift build passes; isolated Swift tests 42 cases / 2 existing
skips; all 22 runtime tests pass. Dot browser regression covers incoming rows
without assistant class, gradient backdrop, translucent colors, blur, bounded
bubbles, rich-text parts, ordinary-chat isolation and disabling. An initial
fixture syntax error and missing fallback accent variable were fixed before
the final passing run. Whitespace checks pass. Local milestone only.

## 2026-09-30 — Your dot appearance section, local

Added a dedicated Your dot sidebar destination with blue Dot / grey self
bubble defaults, color pickers, spacing/corner controls, sample conversation,
and shared appearance Apply/Undo. Preferences migrate older schema-1 files.
Native 26.928.20755 source confirms messaging-root, message-row assistant/self,
message-surface, message-bubble and orbit text-part selectors. CSS clears
full-width row/surface backing, bounds assistant bubbles and keeps writing
blocks/page previews separate. No messages or native nodes are moved.

Fixed refresh-workspace-ui-macos.sh to discover the signed app before checking
its CDP listener; the prior entrypoint failed without initialized app paths.
Hot-applied the four changed runtime files with an exact backup at
~/Library/Application Support/CodexDreamSkinStudio/runtime-backups/before-dot-20260930-100853.
The owned watcher restarted as PID 31043; ChatGPT PID 6029 and its original
09:56:20 start time stayed unchanged. Runtime remains 1.9.23 with this local
patch; no release/version bump, production Studio replacement or publication.
Refresh entrypoint and one-shot renderer verification pass; source, installed
and packaged copies of all four changed files match byte-for-byte.

Review bundle: /tmp/codexstudio-dot-review/CodexStudio.app, debug 0.1.0 / 1000000,
review bundle ID, refreshed runtime cache; strict ad-hoc signature passes.
Visually inspected Your dot page in the staged native Studio: both bubble
colors/alignment, controls and sidebar/footer fit. Exercised spacing increment
and decrement, restoring 14px. Native Apply clicks did not produce an observed
state change; the UI inspection connection later failed / reported the app
changed. Apply/Undo button interactions remain unverified. The refresh script
itself succeeds, and Swift tests cover settings write, undo and rollback.
Direct ChatGPT app inspection is denied by computer-use policy, so actual Dot
page visual appearance remains unverified; Chromium fixture verifies role
colors, narrow assistant wrapping, spacing, clear wrappers, rich text parts,
ordinary-chat isolation and disabling. No test messages were sent.

Validation: swift build passed; 22 runtime tests passed; isolated Swift suite
passed 42 cases with 2 existing skips. Initial in-workspace Swift test signing
failed due to File Provider/Finder metadata; rerun with scratch path
/tmp/codexstudio-dot-swift-build passed. Shell syntax and whitespace checks pass.
New Swift view is 85 lines. Local milestone only.

## 2026-09-29 — Codex Studio 0.1.28 published and verified

Published release commit 7ab913f as v0.1.28; Actions run 36645029766 succeeded.
Release: https://github.com/appleforever11/CodexStudio/releases/tag/v0.1.28
Hosted bundle is 0.1.28 / build 1028000 with runtime 1.9.24. Composer, task,
verification module and VERSION match source byte-for-byte. Latest Sparkle feed
matches release appcast and its Ed25519 signature verifies using the embedded
public key; enclosure length matches the final ZIP. Download hashes match
GitHub's asset digests:
ZIP f3203dc169e2d39df149efcee6ecacbd6dacfe02a6dace3139539442998d9495
DMG a135532e0cc9772e446226988a45cf6a44d06c0bf0a2f44f361d1005a498052b
Feed dd20f301d4acbab5017e510629f617a7273db7ebbcc9441c85bc17729063eb63

Gatekeeper accepted the downloaded app as Notarized Developer ID; app and DMG
stapling validated and DMG checksum passed. Strict deep codesign passed after
removing FinderInfo/ResourceFork metadata from the disposable extracted copy
(the extraction initially carried Finder metadata). Local staged review bundle
/tmp/codexstudio-0128-review/CodexStudio.app has correct app/runtime metadata,
strict signature and matching runtime files. Native Studio was not replaced.
All 20 runtime tests passed; Swift suite passed 41 cases with 2 existing skips.
The previously noted native traffic-light visual verification limitation remains.


## 2026-09-29 — Prepare Codex Studio 0.1.28

Bundles all ChatGPT 26.928 compatibility and glass/chrome fixes from this chat
as runtime 1.9.24. Release notes are RELEASE_NOTES/0.1.28.md. All 20 runtime
tests passed; Swift tests passed 41 cases with 2 existing skips. Isolated
Swift build passed using /tmp/codexstudio-scroll-build. Prior live renderer
verification covers the affected Home/chat/sidebar surfaces; native traffic-light
compositing remains unverified due to computer-use app access restrictions.
The tag workflow will sign, notarize, staple and publish the final ZIP/DMG/feed.


## 2026-09-29 — Clear chat accent frame and feather titlebar seam

Made the main conversation border transparent and removed its edge shadow,
retaining native border dimensions and radius. Added a 28px upper fade to the
sidebar backing mask: its previous abrupt start at y30 extended into the 44px
titlebar beside the native traffic lights. Hot-applied task.css with a backup
at runtime-backups/before-chat-frame-20260929.css. Renderer screenshot confirms
the amber outline is absent and the backing's upper transition is feathered.
Native ChatGPT inspection was rejected by the computer-use app access policy,
so the actual traffic-light compositing remains unverified. Live renderer
verification and three workspace/viewport browser checks passed; editor stays
visible and body offset remains zero. Local only; no app restart or publication.


## 2026-09-29 — Restore sidebar glass through new native wrapper

ChatGPT 26.928 adds [data-slate-sidebar-content] around the existing rounded
ConversationSidebar. Its 65% opaque native fill darkened the glass and left a
square backing visible around its inset corners. Cleared only this wrapper's
background in wide-art mode. Existing 20px rounded glass, 36px blur and independent
scroll container remain unchanged. Hot-applied matching task.css to the managed
runtime, preserving the prior file at runtime-backups/before-sidebar-glass-20260929.css.
Visually inspected live /Applications/ChatGPT.app 26.928.20755: clear wrapper,
rounded glass and no dark square corners. Sidebar scroll moved and restored,
body offset zero. Workspace Chromium regression and live renderer verification
passed. No app restart, native bundle replacement or publication.


## 2026-09-29 — ChatGPT 26.928.20755 theme compatibility, local

Corrected the Home composer body paint after native motion wrappers were added,
and removed the solid sticky-footer backdrop plus its separate upper gradient.
The composer keeps its own themed surface and native dimensions/controls.
Verification now selects visible shell/composer/home nodes because 26.928 keeps
inactive home and thread pages mounted before the active page in the DOM.

Validated in /Applications/ChatGPT.app, version 26.928.20755, Golden Gate,
managed runtime 1.9.23 with this local patch. Home and current chat pass renderer
verification; Home composer 640x98, thread composer 736x98, editor 44px high,
body offset zero. Visually inspected both routes and returned to the current
chat. No test messages were sent. Full runtime suite passed 19 tests, then both
compatibility tests passed after adding the cached-page verification regression
(20 tests total). No Swift source changed or native Studio rebuild performed.

Installed composer.css, task.css, and renderer-verification.mjs match source.
Restarted only the recorded owned injector through stop_recorded_injector and
hot_reapply_theme to load the verification module; ChatGPT PID 99145 and start
time stayed unchanged. New watcher PID 11468. Backup retained beneath
CodexDreamSkinStudio/runtime-backups/before-chatgpt-26928-20260929-180401.
Runtime version remains 1.9.23 pending a separately requested release. Existing
Studio/ChatGPT app bundles and pinned restore point were preserved. Local only.


## 2026-09-28 — Codex Studio 0.1.27 published through Sparkle

Published commit `1acccb8` as tag `v0.1.27`:
https://github.com/appleforever11/CodexStudio/releases/tag/v0.1.27
GitHub Actions run `36428155861` completed the Xcode build, Developer ID
signing, app/DMG notarization and stapling, Sparkle appcast generation, and
release publication. The downloaded ZIP contains app 0.1.27 / build 1027000
and DreamSkin runtime 1.9.23. Its direct-workspace, workspace, preferences,
payload, and VERSION hashes match this source revision.

Hosted ZIP, DMG, and appcast SHA-256:
`b698193c5e751a084c081c73dc2c273cf324e1a632cef9f1e032beedb140dd0e`,
`eceba7bd25f8b3e7662a86c70b3d74a0d3a920392cf309033b11c4a1b4b950f3`,
`23ea4ad48ff2eb8015a5654b8d15392c840c4be6e59a63ae1d66c91d763b763a`.
The `latest` feed matches the release appcast byte-for-byte and advertises
0.1.27 / 1027000 with the v0.1.27 ZIP enclosure. Its Ed25519 enclosure signature
verifies against the public key embedded in the app. Strict `codesign`,
Gatekeeper (`Notarized Developer ID`), app stapling, and DMG verification all
passed on downloaded release assets.

The installed production Studio bundle was left in place; existing users can
install this release through **Check for Updates**. The isolated 0.1.27 review
bundle opened on Canvas and has correct version/runtime metadata, but the native
UI inspector pipe failed during Settings navigation, so those controls still
lack visual inspection. Local Swift build and source syntax/whitespace checks
passed. No automated tests were run in this turn.


## 2026-09-27 — Sidebar scrollbar idle dismissal, runtime 1.9.22

Sidebar scrollbar paint is transparent while idle and accent-colored during
native scrolling, returning to transparent 800ms after the last scroll event.
Native overflow and scrollbar geometry stay intact. Capture listener and timers
are cleaned up on disposal. Direct-workspace browser regression passed.
Hot-applied to /Applications/ChatGPT.app through the managed runtime; live
sidebar scroll verified accent color during movement and transparent after 1s.
Restored original scroll position and inspected /tmp/sidebar-scroll-idle.png.
Pinned restore point retained; no native bundle replacement or app restart.


## 2026-09-27 — Recorded hover timestamps, runtime 1.9.21

Native title tooltips on assistant bubbles and original user prompts now show
localized date/time from existing native turn metadata. Bounded read-only React
ancestor lookup uses recorded assistant ID timestamps, final-start time, and
original turn-start time. Missing times stay unlabeled; no inferred ID dates or
render-time substitutes. Original titles restore on disposal. This depends on
private native metadata and safely skips labels if that shape changes.
Direct-workspace browser test passed with recorded/missing timestamp cases.
Hot-applied to managed runtime; live ChatGPT title attributes verified for
assistant messages and original user prompt. No layout changes or restart.
Pinned restore point retained.


## 2026-09-27 — Separate update bubbles, runtime 1.9.20

Response decoration now targets individual assistant messages instead of the
whole turn branch. Progress updates and final answers have independent glass
bubbles; tool rows and user replies no longer share their outer backing.
No native nodes are moved. Three targeted browser/preferences tests passed,
including multiple sibling updates and cleanup. Hot-applied to the installed
managed runtime and inspected in /Applications/ChatGPT.app: six decorated
messages, zero bubbles containing multiple assistant messages. Screenshot:
/tmp/separate-updates.png. Composer and sidebar dimensions remain unchanged;
pinned restore point preserved. No app restart or native bundle replacement.


## 2026-09-26 — Restore native composer spacing, runtime 1.9.19

Removed all three empty-composer geometry overrides introduced in 1.9.15:
body vertical padding, input-layout padding/minimum height, and editor sizing
variables. Native composer spacing now applies again. Hot-applied and visually
inspected in /Applications/ChatGPT.app; body padding is back to 0px and the
model remains visible. Native empty composer measures 98px high (the previous
custom compact sizing was 94px); this is a restoration, not a new height rule.
Right-card spacing and pinned restore point preserved. Direct-workspace browser
regression passed. No native bundle replacement or restart.


## 2026-09-26 — More space beside the floating card, runtime 1.9.18

Reduced the summary wrapper width from 410px to 378px, preserving its 420px
bounded height and right inset. Live ChatGPT at 1603x796 now has a 36.5px gap
between the chat/composer edge and summary (previously 4.5px); actual card
372x420 after native wrapper padding. Screenshot inspected after hot apply to
/Applications/ChatGPT.app; model selector remains visible. No app restart or
native bundle replacement. Direct-workspace Chromium regression passed.
Installed runtime VERSION and CSS updated; pinned safety restore remains intact.


## 2026-09-26 — Bounded floating summary correction, runtime 1.9.17

User clarified the highlighted target: a wider card near the upper right,
not a full-height sidebar. Removed the vertical stretch; wrapper width targets
410px and the card height is bounded at 420px, shrinking to available space on
short windows. Native edge insets, internal scrolling, glass and collapse remain.
Live measured card: x1189/y50, 404x420 (native wrapper padding accounts for 6px),
bottom470 in the 796px-high viewport. Screenshot inspected and body offset zero.
Chromium direct-UI regression passed, including 410x420 fixture sizing and
shrinking to a 350px available height. Applied locally; pinned restore unchanged.

## 2026-09-26 — Right panel fills its native column, runtime 1.9.16

Removed the artificial 260px width. The glass summary now fills the native
300px floating column and its available height, preserving the app's insets.
Only the verified summary wrapper chain is stretched; the chat's geometry and
scroll containers remain unchanged. Collapsing hides the stretched wrappers
as well so they cannot intercept input over the conversation.

Live inspection: panel x1293/y50, 300x736 inside a 1603x796 viewport, leaving
10px at the right and bottom. Model selector remains visible and body offset
is zero. The existing Chromium direct-UI check passes with assertions for
full-width/full-height sizing, resizing, and hide/reopen. Preserved runtime
1.9.15 at `runtime-backups/before-panel-fill-20260926-214642` beneath the
CodexDreamSkinStudio application-support folder. Pinned 1.9.13 is untouched.
Applied locally without restarting ChatGPT; no native app replacement or push.

## 2026-09-26 — Direct ChatGPT ergonomics, runtime 1.9.15

Implemented in the running ChatGPT renderer, with no new Studio UI changes:
- Narrower 260px glass summary with Hide panel / Outputs & sources toggle.
- A keyboard-accessible Outline popover that jumps to loaded user requests.
  Uses the browser top layer to escape titlebar clipping; opening it does not
  scroll the document or move the toolbar.
- Single-line sidebar excerpts and secondary row actions on hover/focus;
  native unread and working indicators remain intact.
- Compact empty composer that expands for content. **The user rejected the
  experimental Options disclosure: removed it and keep the native model and
  effort selector visible at all times. Do not hide it in a future redesign.**
- Stronger final-answer surfaces, native completed-work disclosure labeled
  Work details, and a reversible fallback disclosure for loaded tool content.
  Active work/approval controls are not automatically collapsed.
- Consistent glass for native menus/search and softer wallpaper behind text.
- Output cards with wrapping filenames, enlarged native thumbnails/file icons,
  native Open actions and Reveal in Finder for listed local files. This does
  not generate new PDF or website thumbnails when the app supplies only icons.
  The Finder bridge accepts only existing files listed in the native Outputs
  section of the active app renderer; it uses bounded argument-based execution.

Validation: 18 runtime tests passed, with subsequent targeted direct-UI checks
passing after the model-visibility correction. Browser tests cover popover
clipping, request navigation, panel toggles, compact/typing composer states,
model visibility, details, preserved file actions and cleanup. Live screenshot
inspection confirmed the model label, output card and reveal control, narrower
panel and unclipped outline. Exercised panel hide/reopen and outline open/close;
body scroll offset remained zero. No chat messages were sent.

Installed runtime is 1.9.15. Preserved an additional exact pre-change runtime at
`~/Library/Application Support/CodexDreamSkinStudio/runtime-backups/before-direct-ui-20260926-213739`.
The pinned stable 1.9.13 restore point still verifies. Runtime source and installed
assets are checked independently; no installed ChatGPT/Studio app bundle was
replaced and no release or push was performed. Prior native Studio visual
verification remains outside this direct-app change.

## 2026-09-26 — Workspace glass and reading improvements, local runtime 1.9.14

On `codex/workspace-ui-improvements`, based on `7254146`. Preserved the
pre-change runtime, Golden Gate theme, preference evidence, and checksummed
manifest at:
`~/Library/Application Support/CodexStudio/RestorePoints/stable-1.9.13-20260926-204245`.
The safety branch `codex/safety-runtime-1.9.13-20260926` preserves the source base.
`Restore stable appearance.command` verifies the backup, retires only the
identity-checked injector, restores runtime/theme files, and verifies a hot
reapply. It preserves replaced files and does not replay historical PIDs or
account settings. Tested a real 1.9.14 -> 1.9.13 -> 1.9.14 round trip; ChatGPT
PID 3152/start 20:25:29 stayed unchanged. The pinned backup still verifies.

Implemented and live-applied:
- Shared glass for the left conversation sidebar and right summary bubble,
  including clear sticky headers. Actual renderer computed background, blur,
  and shadow match exactly; inspected the live screenshot. Root/body offsets
  remain zero, retaining the prior bottom-strip fix.
- Independent sidebar/chat appearance preferences in `workspace-ui.json`,
  strictly validated before injection and watched across atomic replacements.
- Response-branch backing without reparenting native nodes; title wrapping and
  adjustable row spacing. Status badges use native working/attention/completed
  evidence; idle is never guessed to mean successful completion.
- Return to latest with new-activity indication; visible-anchor protection
  after deliberate scrolling. Native overflow and document geometry remain intact.
- Expanded native search excerpts, loaded-text highlights, and return to the
  saved search query. Dates are added only when native datetime metadata exists;
  the runtime does not invent missing metadata or fetch conversation history.
- A Reading view button reduces wallpaper detail, narrows the transcript, and
  hides the summary card without changing the persisted native panel state.

Studio source includes a Workspace appearance card in Settings > General and
Live editor, explicit Apply, one-level Undo, rollback on failed verification,
and a link to the pinned restore point. The longer conversation preview adds
paragraphs, lists, code, and comparisons. Its appearance is an approximation,
not a pixel-identical embedded ChatGPT renderer.

Validation and remaining boundary:
- 16 Node tests passed, including real Chromium shared-glass cascade, sticky
  headers, reading anchors during growth, latest/activity, focus toggles,
  search return/highlights, native status handling, and cleanup. Existing
  viewport/scroll checks at two sizes remain green.
- Swift build passed using `/tmp/codexstudio-scroll-build`; Swift tests passed
  41 cases with 2 existing fixture-dependent skips, including apply/undo and
  failure rollback. The ordinary workspace Sparkle cache was not repaired.
- Latest staged review: `/tmp/codexstudio-workspace-final/CodexStudio.app`,
  version 0.1.26 / runtime 1.9.14. Refresh the local build asset mirror when
  staging same-version runtime source edits.
- Opened the earlier `/tmp/codexstudio-workspace-review/CodexStudio.app` and
  observed Canvas. Native computer-use then failed repeatedly with “Sky
  Computer Use native pipe closed before response,” including after reset.
  **New native Settings/Live editor screens still need visual inspection.**
  Do not claim full native UI smoke coverage or replace the installed Studio
  app on the basis of build/test success alone.
- Live renderer screenshot/measurements use the app's existing verified local
  debug endpoint. No chat messages were sent. The native ChatGPT installation,
  theme library, favorites, drafts, and installed Studio app remain intact.

Changes are local; no push or release. The runtime enhancements are active;
native controls are in the staged review build, not `/Applications/CodexStudio.app`.

## 2026-09-26 — Bottom strip reproduced and corrected locally

Starting from clean `7d1f693`, reproduced the user's full-width bottom strip
in the running ChatGPT 26.924.20706 renderer. The sidebar's decorative
`::before` extends 72px below its host, producing a body scrollHeight of 864px
inside a 796px viewport. Native `overflow:hidden` permits focus/programmatic
scrolling: setting body.scrollTop to 60 moved the shell up 60px, hid the mode
switcher, and exposed the same wallpaper strip shown in the user screenshot.
The prior fade-only fixes did not address that outer document offset.

DreamSkin 1.9.13 uses `overflow:clip` on the themed html/body only. Applying it
resets an existing body offset and prevents subsequent outer scrolling, while
the native sidebar and conversation remain independent scroll containers.
No changes to native thread scrolling, composer geometry, or event handlers.

Verification:
- All 14 Node runtime tests passed, including real Chromium layout checks at
  1440x900 and 800x600. The fixture reproduces the old 60px displacement,
  verifies recovery and prevention, focuses/scrolls the composer and sidebar,
  and checks both directions in the nested scroll panes. Set
  `DREAM_SKIN_TEST_CHROMIUM` on hosts without Chrome at the default macOS path;
  the two browser checks explicitly skip when no browser is available.
- Updated the stale flash-guard assertion to reflect the already-shipped
  idle-and-streaming paint rule; it previously required the removed Stop-only
  selector. No paint-rule implementation changed in this milestone.
- `swift build --product CodexStudio --scratch-path /tmp/codexstudio-scroll-build`
  passed. The normal workspace build still fails on its missing Sparkle
  framework Info.plist, as in the prior handoff; its cache was preserved.
- Staged `/tmp/codexstudio-scroll-review/CodexStudio.app`, version 0.1.26 /
  1026000, review bundle ID, runtime 1.9.13. Strict deep signature verification
  passed. This review app was built, not launched or installed over Studio.
- Source, staged runtime, and installed shell.css SHA-256 all match:
  `595791a4cecb119d24445998e28e8481d7eae558aa10b7ae320b30e604e8655d`.
- Installed VERSION and shell.css with a backup at
  `~/Library/Application Support/CodexDreamSkinStudio/runtime-backups/viewport-scroll-20260926-203512`.
  The existing hot-reapply operation retired the older watcher and started
  watcher PID 22546; ChatGPT PID 3152/start 20:25:29 stayed unchanged.
  Live verification passed with Golden Gate, version 1.9.13, payload revision
  `b12581d2587176b11b57`, and visible sidebar/composer.
- Exercised Search > Swiftcord > Swiftcord Support Contact, wheel-scrolled
  the 5212px conversation up and down (-400 to -150), wheel-scrolled the
  sidebar both ways, focused the composer, and opened New chat. Body offset
  remained zero; the main pane ended at 792px in a 796px viewport (native 4px
  inset). Inspected captured renderer images for the conversation and home;
  the strip was absent and mode label visible. Restored this chat afterward.
  These checks passed; they do not exhaust every intermittent scrolling case.

Changes are local only; no Git push, Sparkle publication, or installed Studio
app replacement was performed. The running theme and future local builds
contain the fix. Existing themes, favorites, drafts, and artwork were preserved.

## 2026-09-26 — Codex Studio 0.1.26 published

Published release commit `1c08179` as tag `v0.1.26`:
https://github.com/appleforever11/CodexStudio/releases/tag/v0.1.26

GitHub Actions run 36252236649 completed debug/release builds, Developer ID
signing, Apple notarization and stapling, signed Sparkle appcast generation,
and release asset publication. The public `latest` Sparkle feed is valid XML,
matches the release appcast byte-for-byte, and advertises 0.1.26 / 1026000 with
a Sparkle EdDSA signature. ZIP SHA-256:
`a5cc89cc1e97b5d4c79a749964e2cbb6c1da8ccfcdd97ecbd23c173c095cd11c`; DMG:
`a44feae60c7c7bfc26a4e4e8ad2ccf64fe8b7d868c91b5f2ca9db8e60f9245bc`;
appcast: `28236127fbf336dcfdd1aa8e1dd1cc83bb7025503d906f2b5f2b84ae33195221`.

The downloaded ZIP contains app version 0.1.26 and DreamSkin runtime 1.9.12;
its `task.css` matches source. Strict `codesign` verification passes and
Gatekeeper reports `Notarized Developer ID`. The fixes remove the redesigned
thread's lower fade overlays without changing scroll/composer geometry,
restore the active ChatGPT/Codex switcher label, and add restrained glass
backing to assistant turns. The user confirmed the hot-applied appearance in
the themed ChatGPT 26.924.20706 session. That session (PID 4987) and its watcher
(PID 5102) remained running; use **Check for Updates** to install 0.1.26.

The normal workspace SwiftPM cache had an invalid Sparkle checkout and an
incomplete framework artifact; both were preserved under
`.build/cache-quarantine/sparkle-20260926`. A clean temporary scratch build
succeeded and the local debug bundle was staged before release.

## 2026-09-25 — Codex Studio 0.1.25 published and installed

Published release commit `de0f93b` as tag `v0.1.25`:
https://github.com/appleforever11/CodexStudio/releases/tag/v0.1.25

GitHub Actions run 36214555402 completed the debug/release builds, Developer
ID signing, Apple notarization and stapling, signed Sparkle appcast generation,
and asset publication. The appcast served at the existing “latest” feed URL
matches the release asset byte-for-byte and advertises 0.1.25 / 1025000 with a
Sparkle EdDSA signature. ZIP SHA-256:
`b5fa25a921a4d5e15f3917eb82148d657b80f3975c89dcf46d7bea1b6b387f2f`; DMG:
`d38552b58deb29225f5166c373f0028da8a15fb930332d19506460661882736c`;
appcast: `1346900f5933eea43135edcdee4153e0ed6e0e5c45dd2ed1abc9f12109449452`.
The downloaded app passes strict `codesign` verification and Gatekeeper
reports `Notarized Developer ID`.

The release includes the finalized rounded liquid-glass sidebar CSS and
DreamSkin runtime 1.9.11, which allows existing 1.9.10 installs to receive the
stylesheet. The current Mac updated through Sparkle from Codex Studio 0.1.24 to
0.1.25 / 1025000; its installed runtime is 1.9.11. Golden Gate remains
selected/applied, with 704 themes, 4 favorites, and 8 recent items. Installed
CSS hashes match the release source. A one-shot live injection reports runtime
1.9.11, the expected payload revision, and visible sidebar/composer geometry.
The final verifier's overall pass remains unavailable while the ChatGPT window
is backgrounded; Computer Use denied direct access to that app for a visible
screenshot.

## 2026-09-25 — Codex Studio 0.1.24 published

Published release commit `35436fa` as tag `v0.1.24`:
https://github.com/appleforever11/CodexStudio/releases/tag/v0.1.24

The release bundles DreamSkin runtime 1.9.10 with the ChatGPT/Codex 26.924.20706
conversation, composer, scrolling, switcher, sidebar, and titlebar fixes. The
downloaded release ZIP contains app version 0.1.24 / build 1024000 and runtime
1.9.10; its bundled `task.css` matches the published source. The ZIP SHA-256 is
`45f924ac847eff98ea80e73579a127a84bf66dfb1025605467611366d6c26157`.

GitHub Actions run 36208420348 completed every release step successfully:
release builds, Developer ID signing, Apple notarization and stapling, signed
Sparkle appcast generation, and GitHub asset publication. The downloaded app
passes strict `codesign` verification and Gatekeeper reports `Notarized
Developer ID`. The hosted “latest” appcast is valid XML, advertises 0.1.24 /
1024000, and points at the v0.1.24 ZIP with a Sparkle EdDSA enclosure
signature. The hosted DMG SHA-256 is
`fa08b92ddffc0d0da8a1f5f4a126ff41d835e6288870f63dd184d4d8924cadc6`; the
hosted appcast SHA-256 is
`b0d9a8ed7b84d3b4f79be81b79221b417e0ec52b0001fc9c0c29481a34f07c7e`.

The existing public Sparkle URL remains unchanged. The release is available
through **Check for Updates**; automatic installation remains disabled. No
other Mac was updated as part of this publication.

## 2026-09-18 — 0.1.22 published and installed through Sparkle

Published tag `v0.1.22` / release commit `23abb9e`:
https://github.com/appleforever11/CodexStudio/releases/tag/v0.1.22

GitHub reports the release as public and all three asset digests match the
local signed artifacts below. The public latest appcast matches byte-for-byte.
Installed Studio 0.1.21 found 0.1.22 through Check for Updates, downloaded it,
and completed Install and Relaunch. `/Applications/CodexStudio.app` now reports
0.1.22 / 1022000; all 104 runtime files match the verified release candidate.
Canvas shows Golden Gate applied, Connected to ChatGPT 26.915.31029,
704 themes, 4 favorites and 8 recent items. The active runtime remains 1.9.8.
ChatGPT PID 5526/start 09:53:59 stayed unchanged throughout the update.
The remaining limitation is direct visual inspection of ChatGPT's welcome
screen, which Computer Use denies; full-layout fixture evidence is detailed
below and in the compatibility report.

## 2026-09-18 — 0.1.22 welcome-container correction validated locally

The user's follow-up screenshot showed 0.1.21 did not fix outer centering.
The previous heading-only fixture missed the full native ancestor chain.
Runtime 1.9.8 excludes modern home-composer-layout roots from the obsolete
first-child hero geometry in home.css, controls.css and task.css.

Full-layout reproduction at 1440px measured 297px drift before the change,
zero after it. Seven cases spanning 360–1440px, all art safe-area modes,
long names, no selected project and a preceding banner had zero center delta
and no horizontal overflow. Wide/narrow fixture screenshots were inspected.
Direct ChatGPT UI access remains denied by Computer Use; this is not live
visual confirmation of the user's welcome screen.

Release candidate `/tmp/codexstudio-release-0.1.22/CodexStudio.app`,
0.1.22 / 1022000, was built and launched. Live editor > Apply source theme
completed with Golden Gate still active. Saved runtime state records 1.9.8,
ChatGPT 26.915.31029, and unchanged ChatGPT PID 5526/start 09:53:59.
Installed Studio remains 0.1.21 pending the release updater check.
All 704 themes, 4 favorites and 8 recent entries remain present.
Backup of prior runtime/state: `/tmp/codexstudio-pre-0122`.

Release build passed; 40 Swift tests passed with 2 optional network skips;
12 Node tests passed. All 104 packaged and installed runtime files match the
build snapshot. Connection > Inspect again reports Ready for runtime 1.9.8.
ZIP and DMG notarization accepted; staples validated and Gatekeeper accepted
the app as Notarized Developer ID. Sparkle signature verification passed;
feed version/build are 0.1.22 / 1022000. Publication is next.

Artifact SHA-256:
- `CodexStudio-0.1.22-arm64.dmg`: `07a46d3e3ac88991cdd140389423c7dc0596f585a2ae01cf54368f885c44e254`
- `CodexStudio-0.1.22-arm64.zip`: `3085259f1c230941203b49862efdd168f9291fd99c665c2e55bd6938faf22c84`
- `appcast.xml`: `1336c42f9c24fa0a9010358d98f08c91a49db3be1ff00bda4cda9808fb712ee8`


## 2026-09-17 — Codex Studio 0.1.21 published to Sparkle

Published release commit `8dad996` / tag `v0.1.21`:
https://github.com/appleforever11/CodexStudio/releases/tag/v0.1.21

The public latest appcast serves 0.1.21 / 1021000. Its downloaded bytes match
the generated feed, and GitHub reports all three uploaded assets with the
same SHA-256 digests recorded below. Sparkle's `sign_update --verify` also
accepted the ZIP enclosure signature. Both archives are notarized/stapled.

The final candidate was launched and exercised at
`/tmp/codexstudio-release-0.1.21/CodexStudio.app`; the installed application
at `/Applications/CodexStudio.app` still reports 0.1.20. Computer Use reported
that the Mac was locked before the installed updater download/relaunch test,
so that test remains pending manual unlock. Do not describe the installed
app itself as upgraded yet. The separately installed theme runtime and active
Golden Gate session were upgraded and verified at 1.9.7 without restarting
ChatGPT. Prior installed app and runtime are preserved under
`/tmp/codexstudio-pre-0.1.21/`.

## 2026-09-17 — Codex Studio 0.1.21 release validation

Final candidate: `/tmp/codexstudio-release-0.1.21/CodexStudio.app`, version
0.1.21 / 1021000, runtime 1.9.7. Built from an isolated committed-source
snapshot because iCloud-backed working-tree reads stalled. Compiled Swift
inputs and all 104 runtime files were checked against the release source.

The current native heading shape is centered with safe project-name wrapping.
A live Apply through Studio exposed a second upgrade defect: the old watcher
was reused across engine versions. Hot apply now retires an older recorded
watcher before injecting the new payload; process identity checks remain in
place. Studio's Apply source theme succeeded, state records runtime 1.9.7,
Golden Gate active, and ChatGPT 26.915.31029 / build 9771. Connection > Inspect
again reports Ready. ChatGPT PID 65112 retained its 20:33:09 start time.

Release-package QA also exposed missing local Apple shelves after the fresh
catalog scan. Studio now discovers local-only packs already cached on this Mac
and can install them into the managed library on demand. Source/license
metadata and release packaging filters are preserved; Apple artwork is not
included in the published artifacts. Final staged Canvas shows 704 themes,
4 favorites, and 8 recent items, including 23 macOS, 278 iOS, and 268 iPadOS
wallpapers. No draft or favorite edits were made.

Validation: release build passed; Swift suite executed 40 tests with 2 optional
network tests skipped and no failures; 12 Node tests passed, including older
watcher retirement and refusal when retirement fails. The isolated heading
fixture passed at 1000px and 360px with long project names. Strict nested
signature validation passed. Direct ChatGPT screenshot/interaction inspection
remains denied by Computer Use, so heading visual QA is the isolated fixture;
Studio UI, deployed runtime identity, and real Apply verification are separate
confirmed checks. ZIP and DMG notarization were accepted, both staples validated, and Gatekeeper
accepted the app as Notarized Developer ID. The signed feed advertises 0.1.21 /
1021000 and retains the existing update endpoint and public key. Publication is verified in the entry above. Final SHA-256 digests: ZIP
`f263448840bbfa13bf023039a9e201162166ba7871fe8e8afa80a0f218b0591c`, DMG
`2fe2cc5077bd7505d684a03e6ddd01be934e7dfc87f852e5e7406121080a5f16`, feed
`f0994b59fb01996f5b68272de6a0411d8cbf981233bfe6175271b1b0bc113d53`.

## 2026-09-17 — ChatGPT 26.915 welcome-heading compatibility

Installed ChatGPT is 26.915.31029 / build 9771. Runtime source 1.9.6 centers the
current group/title welcome-heading shape, removes the injected project-picker
prefix from its inline sentence, and bounds long-name wrapping. Ten runtime
tests and an isolated browser fixture (1000px/360px, including an unbroken long
name) passed. Live UI inspection was denied by Computer Use for com.openai.codex;
production runtime/application deployment and live verification are outstanding.

The September 13 deployment handoff records ChatGPT 26.908.40834 with runtime
1.9.5; the earlier capability check recorded 26.903.71938 / 8576. No matching
old app archive was located, so a full old/new asset diff is unavailable. Current
packed-ASAR hashes and the precise findings/limits are in
[the compatibility report](docs/compatibility/chatgpt-26.915.31029.md).


## 2026-09-13 — Keep active task surfaces paintable

The supplied recording `/Users/kevinhowe/Desktop/Screen Recording 2026-09-13
at 12.34.21 PM.mov` captures a real three-frame, approximately 50 ms blanking
event in the central task thread. The sidebar, header, composer, and window
remain visible while the immersive artwork shows through the native thread
handoff; the artwork itself is static and is not the source of the flash.

The first mitigation in runtime `1.9.4` used a dark opaque thread overlay and
did not stop the flashing. Live inspection then identified the stronger cause:
Codex wraps the active conversation in a `[content-visibility:auto]` host, which
can skip the whole subtree for a compositor frame while streaming children are
replaced. Runtime `1.9.5` removes the ineffective dark veil and forces that
host to remain paintable only while a task is active, preserving the normal
themed artwork/gradient. The 250 ms idle-time parts reconciliation remains in
place so streaming updates do not compete with native paint.

Validation: all 10 Node runtime tests passed; the staged app reports version
`0.1.20 (1020000)`, embeds runtime `1.9.5`, and passes strict code-signature
verification. The exact staged bundle was installed at
`/Applications/CodexStudio.app`; the prior app was preserved at
`/tmp/codex-studio-pre-1.9.4.P7Snyk/CodexStudio.app`. Studio was reopened from
the installed bundle. The live ChatGPT renderer was re-injected without
restarting ChatGPT and reports runtime `1.9.5`, Golden Gate, and an active
session. A temporary hidden Stop-control probe in that live renderer computed
the host as `content-visibility: visible`, `contain: none`, and
`contain-intrinsic-size: none`; a fresh real task transition still needs the
user's visual confirmation.


## 2026-09-10 — Capability-aware 0.1.20 release preparation

The runtime now reads its JavaScript version from the bundled `VERSION` file,
and the CDP layer classifies Codex pages, avatar composition surfaces, external
pages, and embedded webviews separately. Studio adds a read-only Connection
capability panel that reports the installed ChatGPT app/build, loopback/CDP
health, bundled Node and CLI versions, app-server support, and feature flags.
The navigation rail is opaque to prevent the Codex window behind it from
bleeding through, and the sidebar branding now identifies Codex Studio.

Review bundle: `/tmp/codex-studio-capability-review/CodexStudio.app`, bundle ID
`local.kevinhowe.CodexStudio.review`, app version `0.1.20`, runtime `1.9.3`.
The review bundle was launched and the Canvas plus Settings > Connection
surfaces were inspected. It reported ChatGPT `26.903.71938` / build `8576`,
CDP `1.3`, one or more Codex renderer targets, bundled Node `v24.20.0`, CLI
`0.153.4`, and 49 enabled flags. The active production Codex runtime remained
at 1.9.2; no production runtime replacement or theme change was performed.
The isolated native-engine fallback build passed 38 Swift tests (2 opt-in live
tests skipped) and the Node runtime suite passed 8 tests.

The 0.1.20 arm64 release artifact is staged at
`/tmp/codexstudio-release-0.1.20.BShyWG/CodexStudio.app`. Its release bundle
reports app version `0.1.20`, build `1020000`, runtime `1.9.3`, and is signed
with `Kevin Howe (6TYPWRK7SN)`. The ZIP and DMG were each accepted by Apple
notarization, stapled, and validated; Gatekeeper reports `source=Notarized
Developer ID` for the staged app. ZIP SHA-256 is
`ebf6b49e1bac2aaedc76a8b39d59ad371266dca989eb44d9ecddf7d5b0b72837` and DMG
SHA-256 is `23ae1e109079e640fe4db1a8806542c7853e7ff9b7198a1ac75832ddf90b83c0`.
The Sparkle feed was generated from that final notarized ZIP, advertises
`0.1.20` / build `1020000`, and has SHA-256
`ea853836faf37ca5f78428d8d1b60bd7995e9727a5b4190359e03c048ad4d74f`.
Published as commit `778e4ef` / tag `v0.1.20` at
https://github.com/appleforever11/CodexStudio/releases/tag/v0.1.20 with the
arm64 ZIP, DMG, and appcast assets. The hosted appcast is valid XML and the
hosted SHA-256 values match the local artifacts: ZIP
`ebf6b49e1bac2aaedc76a8b39d59ad371266dca989eb44d9ecddf7d5b0b72837`, DMG
`23ae1e109079e640fe4db1a8806542c7853e7ff9b7198a1ac75832ddf90b83c0`, and
appcast `ea853836faf37ca5f78428d8d1b60bd7995e9727a5b4190359e03c048ad4d74f`.
The active production app and installed runtime were not replaced during this
publication.

## 2026-09-07 — Preserve running development sessions

Build-only and launch workflows now preserve active Studio sessions instead of terminating them before compilation. Literal, canonical executable-path checks run before work and before bundle replacement; verification checks the same exact instance. The installed CodexStudio process remained running. Signed-process fixtures and shell validation passed.

Updated 2026-09-05 by the Codex workspace audit.

Existing work includes store/view modularization, bounded runtime process execution, operation completion handling, and layout refinements. Preserve the pre-existing diff; a separate recovery ref records it. No claim of a full current live Apply/Restore check is made by this setup task.

## Validation record

Audit validation: 24 Swift tests passed using `swift test --build-system native --scratch-path /Users/kevinhowe/Library/Caches/CodexAuditBuild/CodexStudio`. The first default-build-engine run stalled and was stopped; this isolated fallback completed. This is a verified fallback for the current toolchain, not a permanent mandate to use the deprecated native engine. No new full live UI pass was performed by this setup task. The separate Node runtime suite also passed all 3 tests.

See [SMOKE_CHECK.md](SMOKE_CHECK.md) for the repeatable workflow. Current audit logs and recovery references are recorded in `/Users/kevinhowe/Documents/ChatGPT/Audit skill.md files/followup/`. Build/tests and live UI observations must be reported separately. Update this section with subsequent results rather than treating a historical check as current.


## MoeWalls Abstract experiment — 2026-09-07

Added a separate Abstract sidebar gallery containing 258 unique entries collected from all 17 MoeWalls category pages. Catalog contains source and thumbnail URLs only. Search and an actual import of Abstract Vibrant Purple And Blue Light Beam were verified in `/tmp/codex-studio-abstract-review/CodexStudio.app` (bundle ID `local.kevinhowe.CodexStudio.review`). Screenshot: `docs/qa/abstract-gallery.png`.

Imports download the short source preview on demand and convert up to 12 seconds to a looping 960px/12fps WebP using local FFmpeg and img2webp. The sample is 425198 bytes. Files and provenance stay in the managed local library and are marked localOnly; no original media is bundled or published. FFmpeg and WebP command-line tools are required for conversion. Source availability may change; individual unavailable previews report an error.

The renderer recognizes animated WebP and substitutes a captured still frame when the document is hidden or Reduce Motion is enabled. Tests: 26 Swift tests passed with the documented native-engine cache fallback (the default engine hit a resource-fork code-sign error); 5 Node runtime tests passed, including motion/fallback/cleanup. The full generated animation payload passed integrity validation and installed into the actual Codex renderer, but the renderer was hidden. Computer Use denied access to com.openai.codex, so visible playback inside Codex is NOT verified. The previously active theme was reapplied from the existing managed active-theme directory. No application installation, installed-runtime replacement, or release was performed; the new runtime is in the review bundle and source. Review bundles intentionally do not auto-install runtime changes.

Next: user-assisted visible playback validation in Codex, then install the new runtime and production build if requested. Do not describe animation as production-ready before that check.

## MoeWalls quality choices and cached refresh — 2026-09-07

Added per-wallpaper source discovery and a quality sheet. Original is preferred by default and displays the post's advertised resolution; Preview is offered only when its media URL exists. The site's official download endpoint is resolved from its download button token, without inventing alternative resolutions. Original imports preserve dimensions at WebP q95 / 15 fps, initially four seconds; the converter can shorten the loop to two or one second to fit the existing 10 MiB renderer limit. It never silently resizes Original. Preview retains the earlier 960px / 12fps conversion. The sheet explains the duration/frame-rate limits. Original and Preview have distinct, collision-resistant local theme IDs.

Media is downloaded on demand to disk, restricted to MoeWalls source hosts and 512 MiB, then removed after conversion. Imports remain localOnly and existing themes remain intact. No MoeWalls media was found in the staged app; only MoeWallsAbstract.json is bundled.

Added a weekly, opening-triggered catalog refresh plus manual Refresh. Failed automatic checks back off for a day, repeated manual checks are throttled for a minute, pagination is sequential, and updates publish atomically only after all pages parse and the advertised total matches. Cached metadata survives offline/errors; refreshing does not download wallpaper media or change imported themes.

Validation: 30 regular Swift tests passed; two opt-in live tests passed separately (the regular run skips them). The original-source integration check downloaded the actual purple/blue beam through the production service, generated a 3840x2160 animated WebP of 7592744 bytes, verified localOnly and removal of the temporary video, and cleaned its isolated test directory. A full catalog service test fetched 17 pages / 258 unique entries, wrote only catalog.json, and verified cache reuse. Five Node runtime tests passed. Final review bundle: /tmp/codex-studio-abstract-review/CodexStudio.app, ID local.kevinhowe.CodexStudio.review. The initial Computer Use “Invalid app” discovery issue cleared with the fresh review instance. The quality sheet, both source choices, and an actual Original import were subsequently verified in the app; its success message selected the new Original theme, whose animation is 3840x2160 / 60 frames. No production app/runtime replacement, theme apply, push, or release in this milestone.


## Larger previews, glass controls, and animation crash repair — 2026-09-07

The Abstract grid now uses larger clickable cards (320px minimum, 28px column / 32px row spacing) instead of the dense 230px grid. Clicking any card immediately opens an 840px-wide artwork preview using the largest advertised still image. Original/Preview quality options and Download use native Liquid Glass controls on macOS 26+, with bordered fallbacks on older systems. Source discovery stays on demand.

The user reported SIGABRT in review process 25535 on macOS 27 (26A5425a) after pressing Preview animation. The supplied stack pinpoints superclass-metadata initialization in _AVKit_SwiftUI when constructing VideoPlayer. That wrapper has been removed. A narrow WKWebView representable now plays the selected WebM using a generated video-only document, nonpersistent storage, restrictive CSP, no third-party page scripts, bounded status reporting, and teardown on close. A standalone AVFoundation probe also reported this site's WebM unplayable via AVURLAsset; WebKit playback is verified instead. Do not reintroduce SwiftUI VideoPlayer for this preview path without testing this OS/runtime combination.

Actual UI checks in /tmp/codex-studio-abstract-review/CodexStudio.app: larger grid and artwork layout inspected; Original/Preview glass selection toggled successfully; Patrick Bateman animation advanced from 0 to 12 seconds at 1280x720; Back to image, restart, close during playback, and opening Purple/Blue Beam afterward all completed without a crash. Source choices correctly displayed 2560x1440 for Patrick and 3840x2160 for Purple/Blue Beam. Local Original downloads retain full dimensions; the streaming site preview is explicitly labeled as potentially lower quality. Gallery screenshot: docs/qa/moewalls-spacious-gallery.png; large preview: docs/qa/moewalls-quality-sheet.png. Final automated checks: 32 regular Swift tests passed (two opt-in live checks skipped in that run and passed separately), five runtime tests passed, and staged bundle signature verified. The production app and active Codex wallpaper remain untouched.

## Pink Wave Sunset unavailable Original recovery — 2026-09-07

The reported Original failure was reproduced: the official go.moewalls.com download endpoint returns HTTP 303 to moewalls.com/error-file (err=1005), which serves a file-not-found HTML page. The advertised original is 1920x1080. The live Preview URL still returns a 951235-byte video/webm. Do not claim the original is permanently deleted or that the source exceeded 512 MiB.

Separated missing files, rate limits, HTTP failures, HTML responses, empty downloads, unsupported redirects, and true size-limit errors. Size-triggered transfer cancellation is tracked under a lock so it reports the actual limit. Failed imports now reopen the same large preview with the attempted quality and actionable error, preserving the selection until the user explicitly chooses another quality.

Verified in /tmp/codex-studio-abstract-review/CodexStudio.app: Original failed with the new file-not-found message and returned to the quality panel; selecting Preview and importing then completed successfully as Pink Wave Sunset · Preview in the managed local library. Original remains the preferred quality after testing. Existing active Codex artwork was not changed. 33 regular Swift tests passed (2 opt-in live tests skipped); staged signature verified. No push, release, or production app replacement.

## Abstract library sorting and filters — 2026-09-07

Added persistent Abstract library controls for Recommended, Newest, Name, Largest preview, and Recently viewed sorting, plus All, Imported, Favorites, and Large previews filters. Recommended prioritizes favorited/imported items, then recent views, then MoeWalls source order. “Large previews” is based on the largest catalog image width (1920px or higher), not an unverified claim about the original video resolution. Cards show Imported and Large preview badges, and opening a card records it in a bounded recently-viewed list. Sort and filter choices are stored in AppStorage and survive relaunch.

Cached imported/favorite IDs prevent the sort comparator from repeatedly scanning the full local theme library. The first review pass exposed that repeated scan as a main-thread responsiveness problem; after caching, the Abstract screen opened and sorted normally. Review evidence is in `docs/qa/moewalls-sorted-filtered.png`.

Verification in `/tmp/codex-studio-abstract-sort-review/CodexStudio.app`: sort menu exposed all five choices; Name reordered the first entries alphabetically; Large previews reported 234 of 258; Imported reported the three local Abstract imports; after terminating and reopening the review app, Name and Imported persisted and again showed three items. Swift tests: 36 passed with 2 opt-in live tests skipped; runtime tests: 5 passed. No production app/runtime replacement, active Codex theme change, push, or release.

## Codex Studio 0.1.19 publication — 2026-09-07

Published commit `33eb910` as tag `v0.1.19` at https://github.com/appleforever11/CodexStudio/releases/tag/v0.1.19. The local release build used the Developer ID Application identity `Kevin Howe (6TYPWRK7SN)`, produced an 11 MiB arm64 ZIP and DMG, passed strict nested code-signature verification, and was accepted, stapled, and validated by Apple notarization. Gatekeeper reported `source=Notarized Developer ID` for the staged app.

The Sparkle appcast was generated from that exact notarized ZIP with the configured Ed25519 key, committed to `appcast.xml`, and uploaded with the ZIP and DMG. The live latest appcast is valid XML, retains the recent 0.1.19/0.1.18/0.1.17 history, and advertises `0.1.19` / build `1019000`; its hosted SHA-256 matches the committed signed feed (`4be0944902a2607875a8157631c81c72979dc7281431d73778bcc2d3cb2706da`). Hosted ZIP and DMG digests match the notarized local artifacts. The GitHub Actions tag workflow was attempted but stopped at its configured distribution-secret validation; manual publication used the verified local artifacts instead.
