# Codex Studio handoff

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
