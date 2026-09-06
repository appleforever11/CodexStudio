# Codex Studio architecture

## Boundaries

- **Views** own layout and interaction presentation. Artwork effects must live inside an explicitly sized host so image intrinsic dimensions cannot expand the window or overlap following sections.
- **StudioStore** is the main-actor presentation coordinator. Its feature extensions separate catalog queries, library loading, navigation, editor changes, desktop actions, and runtime operations. These are organizational boundaries, not independent stores.
- **Services** own file access, imports, runtime installation, and process execution. RuntimeProcessRunner uses nonblocking output reads, bounded diagnostic retention, and a termination grace period.
- **Models** own catalog/release semantics. Filtering is shared across Canvas, Explore, Favorites, and the local library.
- **Support** owns common visual styles, image caching, diagnostics, and the narrow native-window integration.
- **DreamSkinRuntime** is a separate Node/shell runtime. Operation tokens prevent stale completion from completing a newer operation.

## Visual contract

Keep the single window header and finite two-pane shell. The sidebar scrolls independently; its preview and connection controls remain below navigation. Never size the entire sidebar from its ideal content height.

Use translucent material for navigation and control surfaces, wallpaper-derived glow for atmosphere, and explicit image clipping. The Canvas selection inspector appears only when horizontal space permits. Favorite buttons remain separate from the card-selection button.

## Verification

Run SwiftPM tests through the configured macOS toolchain and the runtime tests with:

    node --test Tests/Runtime/*.test.mjs

Stage the app with script/build_and_run.sh and inspect Canvas, Explore, release filtering, Favorites, the editor, and Settings. A successful compile is not visual verification. Do not publish local review builds without explicit release authorization.

The runtime source is packaged separately from the cached local build assets. A runtime source change is not proof that an installed injector has changed; verify package contents, installed version, and an actual operation before claiming the deployed runtime fix.

## Review build

Set CODEX_STUDIO_BUNDLE_ID=local.kevinhowe.CodexStudio.review for side-by-side UI review. This identifier disables automatic runtime/launcher installation and automatic Sparkle startup. It reads the existing local library but does not automatically replace the production injector.

CODEX_STUDIO_USE_CACHED_CATALOG=true avoids repository catalog reads for debug-only UI iteration. Release builds reject this option. Runtime VERSION changes invalidate the build-asset runtime cache automatically.

## Release gate for this overhaul

- Swift tests and Node operation tests must pass.
- Verify Canvas at narrow and wide window sizes, Explore filters, favorite toggles, editor controls, and each Settings section visually.
- Confirm the packaged runtime is 1.9.2 and contains the modular operation-state reconciliation.
- Verify a real apply/relaunch completion before claiming the stuck-overlay issue fixed in deployment.
- Only then sign, notarize, publish GitHub artifacts, and update the Sparkle appcast.
