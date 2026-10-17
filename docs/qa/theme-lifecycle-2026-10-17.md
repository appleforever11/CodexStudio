# Local theme lifecycle acceptance — 2026-10-17

Installed `/Applications/CodexStudio.app` version 0.1.29 / build 1029000, containing runtime 1.9.28. The installed injector is also 1.9.28. Strict nested signing passed, and the installed persistence/health scripts match source. This is a local signed debug build, not a notarized distribution or Sparkle release.

A rollback copy of the prior installed app, runtime and active theme is in `~/Library/Application Support/CodexDreamSkinStudio/local-upgrade-20261017/`. Managed themes, imports, favorites, drafts and the ChatGPT installation were preserved.

## Actual installed-process checks

- Studio registered the signed helper using SMAppService; launchd confirmed a running ServiceManagement-managed job with the expected parent bundle and mapped helper executable. No manual Login Items override was needed.
- A second theme (`claude-warm-paper`) applied and verified. Golden Gate was restored. Theme switches preserved ChatGPT's PID and the helper's PID/run count. The final warm apply took 2.34 seconds.
- The legacy `com.codexthemes.theme-monitor` job and LaunchAgent plist were retired once the native service was confirmed. Its disabled launchd override can remain as historical state.
- Stopping the identity-verified injector triggered helper health recovery in 23.11 seconds without changing ChatGPT's PID. The replacement injector verified Golden Gate.
- After stopping ChatGPT and launching it normally, the helper restored the debug-enabled launch and verified Golden Gate on a new ChatGPT PID. The host restart interrupted the chat, so post-restart evidence was reconstructed from the saved pre-restart state, updated active state and a fresh renderer verification. No elapsed-time claim is made for that check.
- Restore Original removed the live skin, disabled persistence, unregistered the helper and removed active state. Studio correctly reported Offline with an installed, inactive runtime. Reapply registered a new helper and verified Golden Gate again.
- A temporary theme referring to a missing image was rejected during staging; the Golden Gate config stayed intact. The fixture was removed. Connected apply rollback is covered by automated fault-injection tests; no production renderer failure was deliberately injected.

## Fixes found by live testing

Registration now attempts SMAppService registration from both notRegistered and notFound. Native backend detection uses launchd's PID plus the actual mapped executable because macOS may expose the signing identifier in `ps`. Missing or stale native service records safely fall back. Health checks now reject non-active sessions, mismatched theme IDs, old engines and dead watchers while preserving process identity checks. Restore no longer labels an installed but inactive runtime as missing.

The explicit `--verify-local-theme-process <theme-id> <report-path>` and `--verify-local-restore-process <theme-id> <report-path>` launch arguments exercise the same StudioStore actions used by Apply/Restore. Reports include exact app path, service status, result and timing. Normal launches do not activate this mode. Native computer-use clicks/shortcuts remained unreliable, so process acceptance used these real in-app store actions rather than claiming a successful mouse-driven UI test. Sleep/wake, reboot/login and the Settings shortcut's visual interaction were not exercised.

## Automated and packaging checks

34 runtime tests passed. Swift tests ran 42 cases with two existing opt-in skips and zero failures. The production-ID bundle and nested helper passed strict code-signature verification after installation. Cloud-backed source/Git reads stalled during rebuilds, so the canonical build script used a synchronized temporary Swift package mirror and isolated scratch path; cached catalog staging remained debug-only.

Machine-readable results are in [theme-lifecycle-2026-10-17.json](theme-lifecycle-2026-10-17.json). No push, tag, GitHub release or Sparkle appcast change was made.
