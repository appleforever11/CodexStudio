# Bundled Codex theme runtime

This is the local Codex theme runtime used by Codex Studio's apply-and-verify path. The release app copies it to `~/.codex/codex-dream-skin-studio` only when that managed runtime is absent; an existing runtime is preserved.

The runtime discovers the signed official Codex/ChatGPT app, uses its bundled Node executable, and communicates with the local renderer over loopback CDP. It does not modify the official app bundle or its signature. The runtime is derived from the local Codex Dream Skin installation and its original upstream notices and licensing terms remain relevant: <https://github.com/Fei-Away/Codex-Dream-Skin>.
