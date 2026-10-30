# Injection runtime comparison and implementation — 2026-10-29

## Scope and evidence

Compared the local Codex Studio runtime at `336a7f88d43a39c45104bdb71d7f16f56ff51994` (1.9.28) with source snapshots fetched on October 29, 2026:

- [Codex Styler CDP implementation](https://github.com/xuhuanstudio/codex-styler/blob/ee3dce2e69cc2ec884f0567d4475eb33722054e5/apps/desktop/src-tauri/src/cdp.rs), [architecture](https://github.com/xuhuanstudio/codex-styler/blob/ee3dce2e69cc2ec884f0567d4475eb33722054e5/docs/architecture.md), and [managed-session decision](https://github.com/xuhuanstudio/codex-styler/blob/ee3dce2e69cc2ec884f0567d4475eb33722054e5/docs/adr/0001-managed-cdp-runtime.md).
- [CC Theme Mac Codex injector](https://github.com/quanzhankeji/cc-theme/blob/509bb06ce21306e3c32556a91f63b126ca79c558/adapters/mac-codex/scripts/injector.mjs), [surface admission](https://github.com/quanzhankeji/cc-theme/blob/509bb06ce21306e3c32556a91f63b126ca79c558/adapters/mac-codex/scripts/surface-admission.mjs), and renderer under the same adapter.

This is a source comparison, not a runtime endorsement of either competitor. Neither competitor was installed. No competitor code was copied into Studio.

## Detailed comparison

| Area | Codex Studio baseline | Codex Styler | CC Theme Mac Codex | Decision |
| --- | --- | --- | --- | --- |
| Transport | Persistent page WebSockets over loopback CDP, validated page URLs and target classification | Managed loopback CDP session; per-command evaluation sockets in `cdp.rs` | Persistent loopback CDP page sessions | Keep Studio's persistent connections. Replacing Node with Rust alone does not remove renderer or CDP costs. |
| Host launch | Signed official app, identity-checked endpoint, existing session reuse, managed persistence helper | Managed launch with an unused random port | Signed app launch and adapter-specific capability checks | Preserve established host identity checks and reuse. Port changes would affect helper, state, launchers, and recovery without demonstrated benefit here. |
| Initial domain setup | `Runtime.enable` followed by `Page.enable` | Renderer readiness checks on candidate sockets | Persistent session setup in injector | Run independent domain commands concurrently; close on failure. |
| Discovery | Validated `/json/list` inventory, 800 ms steady polling | 200 ms readiness polling; candidate checks concurrent with individual and overall budgets | Repeated target inventory and document-generation reconciliation | Add event-triggered wakeups while retaining validated inventory as authority and a bounded polling fallback. |
| Early installation | `Page.addScriptToEvaluateOnNewDocument`, existing-document bootstrap, generation invalidation | Versioned idempotent scene root with revisioned configuration and compatibility adapters | Early document scripts with renderer/document generations | Keep Studio's early injection. It already exists; adding it again is not an improvement. |
| Navigation readiness | Semantic DOM probe; a destroyed execution context aborts that probe | Readiness timeout, stable target samples | Document identity/generation reconciler with cancellation | Retry only transient context-destruction errors within the existing probe deadline. Do not mask permanent errors. |
| Theme updates | Source watcher, serialized refresh, operation tokens, mutation epoch, lock and previous-theme rollback | Complete revisioned configuration; isolated scene vs semantic styling | Serialized generation reconciliation; stale commits rejected; deferred media transfer | Preserve Studio's existing operation and mutation guards. A full document reconciler or media pipeline migration needs separate evidence and testing. |
| Compatibility | Target contract and shared selector map, DOM readiness and geometry checks | Conservative scene layer and Enhanced semantic adapter | Client/surface evidence, structural landmarks, version/build/signature/renderer evidence | Keep current acceptance gates. Do not pin Studio to a competitor's host hash or silently fall back to reduced styling. |
| Recovery | Native launch/wake helper, shell fallback, owned watcher recovery, pause/restore | Managed session; no resident agent per ADR | Adapter lifecycle and reapplication | Keep working native persistence. Removing it would change the product's normal-launch behavior. |
| Official installation | No signed app bundle changes | No signed app bundle changes | Mac Codex adapter does not mutate `app.asar` | Continue external-only injection. No preload patching, binary changes, signature replacement, or framework modifications. |

## Changes in runtime 1.9.29

1. `discovery-signal.mjs` coalesces discovery notifications and retains a revision counter. Events arriving during HTTP inventory or target setup cannot be lost just before sleeping. Only one watcher-loop wait exists at a time.
2. An accepted live renderer enables `Target.setDiscoverTargets` with a 500 ms command budget. Page creation, information changes, destruction, and the discovery socket closing wake the serialized loop. Worker/iframe creation and destruction do not trigger repeated scans. Event URLs are never used to connect: normal HTTP inventory validation and semantic probing still apply.
3. With event discovery available, the recovery inventory runs every four seconds instead of every 800 ms: a theoretical reduction from 75 to 15 timer-driven inventory requests per minute while idle. This is a scheduling calculation, not a measured CPU or battery improvement. Discovery leadership transfers to an existing live session if the leader closes; unsupported commands are attempted only once per session. Unsupported hosts retain the previous 800 ms steady fallback and fast cold discovery. A host that accepts discovery but fails to deliver an event is still covered by the four-second poll.
4. Stop and operation-state transitions wake discovery waits promptly. Theme reload serialization, operation tokens, pause invalidation, and rollback are unchanged.
5. CDP domain enables run concurrently. Failed setup closes the socket and rejects outstanding work. A socket closing during opening fails promptly instead of waiting for the five-second handshake timer; handshake listeners are cleaned on every outcome.
6. DOM probing retries execution-context destruction/not-found errors caused by navigation. Each evaluation receives only the remaining readiness budget. Closed sockets and permanent errors still fail.

7. The warm launcher now always captures the new watcher start time before publishing state. Previously that assignment ran only on cold launch, leaving a warm launch impossible to pause safely. Two shell-driven regression tests exercise complete and missing process identity.

## Automated validation

- `node --test Tests/Runtime/*.test.mjs`: 45 passed, zero failed or skipped. Includes nine new discovery/connection tests plus existing apply rollback, operation-state, target exclusion, runtime upgrade, source watching, and Chromium renderer behavior checks.
- `swift build --product CodexStudio`: successful in an isolated copy of local HEAD, because workspace iCloud reads and Git status/dependency operations stalled. No Swift implementation changed.
- `swift test` on that isolated package: 42 executed, two existing opt-in skips, zero failures.
- Staged through the repository launcher using `CODEX_STUDIO_SWIFT_PACKAGE_PATH` and an explicit local Sparkle framework path to avoid an iCloud artifact timeout.
- Bundle: `/tmp/codex-studio-injection-review/CodexStudio.app`, version 0.1.31, identifier `local.kevinhowe.CodexStudio.review`, runtime 1.9.29. Strict nested signature verification passed. The five runtime files (VERSION, three modules, and launcher) were byte-compared against source.
- Review app accessibility showed Canvas, Golden Gate applied, 143 local themes, and the connection to ChatGPT 26.1027.30824. No editor or visual layout changes were made. The review app was closed after inspection.

## Measurements and live limitations

- Interleaved 12-sample local connection benchmark: old median 2.433 ms, new median 2.343 ms. This is a small difference and does not establish a meaningful end-to-end apply speedup.
- ChatGPT 26.1027.30824 accepts discovery on a page session. A temporary title change generated a page-information event and woke the discovery signal in about 513 ms, including host title-event delay; the original title was restored. This is not a new-window injection benchmark.
- Owl rejects `Target.createTarget`; no artificial browser window was created. New-window behavior cannot be claimed from that command.
- The native computer-control tool refuses access to `com.openai.codex`. Direct native-window visual checks were therefore unavailable.
- Live acceptance evidence is recorded below after the final recovery check. Visibility failures must not be changed into successful verification.

## Rollback and preservation

Only VERSION, `cdp-session.mjs`, `watch-runner.mjs`, the new `discovery-signal.mjs`, and `start-dream-skin-macos.sh` are overlaid into a full copy of the previously installed external runtime. The runtime directory is swapped with renames; existing installed assets, presets, and other files are retained. The original runtime remains at `/Users/kevinhowe/.codex/codex-dream-skin-studio.before-injection-20261029`.

The installed Codex Studio app is not replaced. No push, release, Sparkle feed change, official ChatGPT bundle modification, or external account action is part of this work. Imported themes, preferences, drafts and favorites are preserved.


## Final live acceptance

External runtime 1.9.29 is installed and active; source, packaged and installed hashes match for all five intended files. Golden Gate (`macos-golden-gate-amber-bridge`) remains active on ChatGPT 26.1027.30824. The same official ChatGPT process remained running throughout.

The first foreground-independent checks correctly failed while only a detached window was visible. Opening the main window resolved the visibility gate without changing verification policy. The warm-launch test then exposed the missing watcher start time described above; the final launcher records a complete PID/path/start-time tuple.

After that fix, the real pause operation succeeded in 2.083 seconds, warm reapply in 2.073 seconds, and independent verification in 1.311 seconds. The verifier confirmed runtime version, exact theme/revision, visible document, geometry, payload, and viewport. Owl's native-window query remains unsupported; the existing visible-document/window fallback passed. Event discovery is enabled in the final watcher log.

Executable and `app.asar` SHA-256 values before/after match; strict official-app signature verification passed. The signed review bundle also passed strict verification. The installed Studio app was not replaced. No sleep/reboot/login or host-update acceptance is claimed, and a new-window latency benchmark remains unperformed. See [machine-readable acceptance](injection-runtime-2026-10-29.json).
