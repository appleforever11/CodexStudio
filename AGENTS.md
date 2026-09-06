# Codex Studio project guidance

A SwiftPM macOS theme browser/editor with a separate Node/shell DreamSkin runtime.

## Working context

Inspect Git state before editing and preserve existing work. Use [PROJECT_STATUS.md](PROJECT_STATUS.md) for the latest handoff, and [SMOKE_CHECK.md](SMOKE_CHECK.md) when verifying runtime changes. Update status after a meaningful milestone or new blocker, not every trivial edit. Keep mutable versions and dependency facts in their existing manifests.

## Commands

- Compile: `swift build --product CodexStudio`.
- Tests: `swift test`; runtime tests: `node --test Tests/Runtime/*.test.mjs`.
- Stage/launch: `./script/build_and_run.sh`; inspect the script for build mode and overrides. The default staging location is `$TMPDIR/codex-studio-local-build/CodexStudio.app`, not necessarily `dist/`.

## Project contracts

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for store extensions, finite sidebar geometry, and runtime boundaries.
- Keep imported themes, drafts, favorites, the managed theme library, and the existing Codex installation intact.
- Apple wallpaper packs are local-only; preserve provenance and packaging filters.
- Runtime source, cached build assets, and the installed injector are distinct. Verify the intended layer before claiming an apply/recovery fix.
- Preserve generation/operation tokens and bounded process output/timeouts.

## Completion

Match checks to the change. Documentation-only edits need link/command review; UI changes need inspection of the rebuilt app on the affected screen. Record the exact bundle and tested interactions. Check running instances before a launcher that may terminate an app by name. Keep Swift source under 500 lines where applicable; split by responsibility only when needed.

Stage explicit intended paths after reviewing the diff. A recovery snapshot records work as found and is not a declaration that it is complete. Make local milestone commits for completed work; push, release, installation replacement, and external account actions require the user's corresponding request.
