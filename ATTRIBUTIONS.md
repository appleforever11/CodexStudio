# Attributions

Codex Studio is an independent implementation created for this repository. It does not copy source code from the earlier Codex Themes application and does not modify the official Codex app bundle.

The earlier Codex Themes project is available at <https://github.com/NBchitu/CodexThemes-App> under the MIT License. Its source, artwork, and any other separately distributed material should retain their own copyright and license notices if reused in the future.

The DockDoor helper includes `Resources/CodexDark.icns`, a packaged copy of the stock Codex dark-mode icon used to identify the themed Codex shortcut. It is a branding asset of the official Codex application, not an original Codex Studio asset; the helper does not modify or replace the official Codex application bundle.

The release bundle includes `Resources/ThemePacks`. Legacy packages are retained as supplied and may have incomplete provenance metadata; Codex Studio does not make a blanket ownership claim over those assets. They must not be described as verified or redistributed in a new release until their rights are established.

New curated packages follow a stricter standard: the artwork must be human-created, traceable, and cleared for redistribution. AI-generated imagery and procedurally mass-produced gallery filler are excluded. Every approved package includes a `LICENSE.txt` file with the real work title, creator, institution or publisher, source record, image source, rights status, and retrieval date. Automated cropping and palette extraction do not replace or obscure the artwork's authorship.

The release bundle also includes `Resources/DreamSkinRuntime` so a clean Mac can perform the same apply-and-verify operation. It is derived from the local Codex Dream Skin runtime and remains subject to its upstream notices and license terms: <https://github.com/Fei-Away/Codex-Dream-Skin>. Codex Studio installs it only when the user's managed runtime is absent and does not modify the official Codex app bundle.

## macOS Era artwork

The `macos-*` collection uses the official Apple wallpaper associated with each major OS X/macOS release, from Cheetah/Puma through Golden Gate. The release references are archived by 512 Pixels at <https://512pixels.net/projects/default-mac-wallpapers-in-5k/>. Apple Inc. and the original wallpaper creators retain their rights; these packs remain marked `localOnly: true` with their provenance records. The user-directed 0.1.6 ZIP and DMG include the offline collection.

Codex Studio's local presentation is limited to deterministic downscaling, JPEG encoding, and generation of interface tokens. It does not claim authorship of, or affiliation with, Apple or the underlying wallpapers.

## iOS and iPadOS artwork

The local `ios-*` and `ipados-*` shelves use official Apple mobile wallpaper artwork preserved by the [SniperGER iOS-Wallpapers archive](https://github.com/SniperGER/iOS-Wallpapers), which documents extraction from the `/Library/Wallpaper` assets in Apple firmware through iOS/iPadOS 17. Current platform reference assets are sourced from Apple's [WWDC26 wallpaper page](https://developer.apple.com/wwdc26/wallpaper/). Apple Inc. and the respective wallpaper creators retain their rights. These packs are marked `localOnly: true`, converted to Mac-ready 2400×1500 derivatives, and included in the user-directed 0.1.6 offline release artifact with their source records intact.

The archive's device-size duplicates are represented by one highest-resolution still per distinct artwork within each platform. iOS 16 and later layered compositions remain identified as static presentations according to the archive's own record; Codex Studio does not claim to reproduce Apple's live or parallax behavior.

Sparkle is included as a Swift Package dependency from <https://github.com/sparkle-project/Sparkle>. Its license and notices are maintained by the Sparkle project.
