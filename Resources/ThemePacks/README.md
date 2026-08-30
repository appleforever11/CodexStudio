# Bundled theme packs

This directory is the install seed shipped with Codex Studio. It is a snapshot of the managed Codex theme library available on the maintainer's development Mac on 2026-08-30, containing 130 validated package directories.

Each child directory is a theme package with a `theme.json` manifest and its referenced artwork. The manifest's author, collection, and any package-level notices are part of the package metadata and must remain with that package. Codex Studio does not make a blanket claim that every artwork asset in this snapshot was created by Codex Studio; review provenance and redistribution rights before adding or shipping a package whose metadata is incomplete.

To add a future bundled theme, add another validated package directory here. The build script copies the complete directory into the app bundle, and the app seeds only missing packages into `~/Library/Application Support/CodexDreamSkinStudio/themes` on first launch.
