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
