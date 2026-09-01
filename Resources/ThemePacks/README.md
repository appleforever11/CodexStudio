# Bundled theme packs

This directory is the install seed shipped with Codex Studio. The legacy snapshot predates the project's provenance-first curation policy, so package validity and artwork redistribution rights are tracked separately.

Each child directory is a theme package with a `theme.json` manifest and its referenced artwork. The manifest's author, collection, and any package-level notices are part of the package metadata and must remain with that package. Codex Studio does not make a blanket claim that every artwork asset in the legacy snapshot was created by Codex Studio.

New bundled artwork must be human-created and traceable to a rights-cleared source. AI-generated imagery and procedurally mass-produced gallery filler are not accepted. Every newly curated package must include `LICENSE.txt` with the work title, creator, institution or publisher, source record URL, image URL, rights status, and retrieval date. Packages with incomplete provenance may be used privately but are not release-ready.

## macOS Era collection

The `macos-*` packages represent the major OS X/macOS release eras: Cheetah, Puma, Jaguar, Panther, Tiger, Leopard, Snow Leopard, Lion, Mountain Lion, Mavericks, Yosemite, El Capitan, Sierra, High Sierra, Mojave, Catalina, Big Sur, Monterey, Ventura, Sonoma, Sequoia, Tahoe, and Golden Gate. Their local cache uses the official Apple release wallpaper associated with each era, archived by 512 Pixels. These are Apple-copyrighted local-only references, not Codex Studio artwork and not release-ready redistribution assets.

Golden Gate uses the official brown-gold wallpaper direction requested for macOS 27. The cache stores a deterministic 2400px JPEG presentation for responsive gallery performance; it does not generate or reinterpret the underlying Apple image.

To add a future release-ready theme, add another validated package directory here. The build script copies only packages that pass the provenance and rights gate into a release app bundle by default. Local-only Apple packs are seeded by `script/import_official_macos_wallpapers.sh` and `script/import_official_mobile_wallpapers.sh` into `~/Library/Application Support/CodexStudio/ThemePacks`; the 0.1.6 offline release was built with an explicit local-only override.

## iOS and iPadOS collections

The `ios-*` and `ipados-*` packages represent distinct still wallpapers associated with iPhone and iPad releases. The importer uses the iOS-Wallpapers archival index for Apple firmware artwork through iOS/iPadOS 17 and the official Apple Developer WWDC26 wallpaper page for the current platform assets. Device-size duplicates are reduced to the highest-resolution still for each artwork, then formatted as deterministic 2400×1500 landscape JPEGs for the Mac gallery. These packages retain the source path, source URL, rights record, and local-only status; the underlying Apple artwork is not Codex Studio artwork and is not release-ready for redistribution.
