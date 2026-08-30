# Bundled Codex theme runtime

This is the local Codex theme runtime used by Codex Studio's apply-and-verify path. The release app copies it to `~/.codex/codex-dream-skin-studio` on first launch and upgrades it atomically when the bundled `VERSION` is newer; an existing newer runtime is preserved.

The runtime discovers the signed official Codex/ChatGPT app, uses its bundled Node executable, and communicates with the local renderer over loopback CDP. It does not modify the official app bundle or its signature. Codex Studio also installs its signed `Codex Themed.app` helper when possible; this is the DockDoor-compatible launcher that starts the stock app through the managed engine and repairs a stock launch after a Codex update. The runtime is derived from the local Codex Dream Skin installation and its original upstream notices and licensing terms remain relevant: <https://github.com/Fei-Away/Codex-Dream-Skin>.
