# Codex Studio

Codex Studio is a standalone native macOS theme studio for Codex. It is intentionally a fresh implementation rather than a fork of the previous Codex Themes desktop UI.

The app icon is an original Codex Studio asset generated for this project and stored as `Resources/CodexStudioIcon.png` with the bundled macOS representation in `Resources/CodexStudio.icns`.

Codex Studio also includes Sparkle 2.9.6 for signed, GitHub-hosted updates. Use **Codex Studio > Check for Updates…** after installing a release build. The Sparkle private signing key is never stored in this repository; only the public verification key belongs in the app bundle.

![Codex Studio Canvas](docs/screenshots/codex-studio-canvas.png)

![Codex Studio Themes](docs/screenshots/codex-studio-themes.png)

![Codex Studio Live Editor](docs/screenshots/codex-studio-live-editor.png)

The first milestone is built around three ideas:

- a fast, explicit apply-and-verify path for switching themes;
- a large local library that can discover the existing managed Codex themes without copying them into this repository;
- a live, inspectable Codex canvas for shaping a theme before applying it.

## Run

```bash
./script/build_and_run.sh
```

The same script is wired into the Codex app Run action through `.codex/environments/environment.toml`.

## Theme sources

Codex Studio looks for themes in:

```text
~/Library/Application Support/CodexDreamSkinStudio/themes
```

It also checks the local WallBuddy app bundle and its adjacent `dist/assets` directory for image assets. The current WallBuddy bundle contains no wallpaper catalog, so the app treats that source as optional and falls back to the managed Codex library.

Applying a managed theme uses the existing local runtime entry point when available:

```text
~/.codex/codex-dream-skin-studio/scripts/switch-theme-macos.sh
```

The app only reports success after the runtime state confirms the requested theme id. If the runtime is missing or the theme is only a visual preview, the UI says so.

## Release artifacts

The release scripts create an Apple Silicon app bundle, signed ZIP, signed DMG, and Sparkle `appcast.xml`. Distribution builds require a Developer ID Application identity and an Apple notarytool credential profile on the build machine. The GitHub Actions workflow uses repository secrets for those credentials and never commits them.

## Project shape

```text
Sources/CodexStudio/
├── App/          app entry point and activation
├── Models/       theme, section, and runtime models
├── Stores/       app state and user actions
├── Services/     theme discovery, import, and Codex runtime bridge
├── Support/     colors, styles, and image artwork
└── Views/        sidebar, canvas, library, editor, and settings
```

Codex Studio is not an OpenAI product and does not modify the official Codex app bundle, `app.asar`, or its code signature.

The implementation in this repository is new code and does not copy the previous Codex Themes application. The local Codex theme runtime and discovered theme artwork remain external to this repository; their creators and licenses should be preserved independently if those assets are redistributed.

See [ATTRIBUTIONS.md](ATTRIBUTIONS.md) for the project provenance and third-party notice policy.
