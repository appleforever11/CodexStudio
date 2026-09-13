# Codex Studio handoff

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
