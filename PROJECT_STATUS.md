# Codex Studio handoff

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
