import Foundation

// Stable entry point for the theme library. Storage, mutation, import, and
// discovery details live in focused extensions beside this facade.
struct ThemeLibraryService {
    static let supportedImageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "heic", "heif"]

    static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var managedThemesDirectory: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexDreamSkinStudio", isDirectory: true)
            .appendingPathComponent("themes", isDirectory: true)
    }

    static var bundledThemesDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("ThemePacks", isDirectory: true)
    }

    static var bundledRuntimeDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("DreamSkinRuntime", isDirectory: true)
    }

    static var installedDockDoorLauncherURL: URL? {
        dockDoorLauncherCandidates.first(where: isManagedDockDoorLauncher)
    }

    static var wallBuddyBundle: URL {
        homeDirectory
            .appendingPathComponent("Codex Projects Restored", isDirectory: true)
            .appendingPathComponent("WallBuddy", isDirectory: true)
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("WallBuddy.app", isDirectory: true)
    }

    static func loadSynchronously() -> ThemeLibraryResult {
        _ = installBundledRuntimeIfNeeded()

        let bundledThemes = scanBundledThemes()
        let localThemes = scanManagedThemes()
        var themeByID = Dictionary(uniqueKeysWithValues: bundledThemes.map { ($0.id, $0) })

        for local in localThemes {
            if let bundled = themeByID[local.id] {
                themeByID[local.id] = bundled.mergingLocal(local)
            } else {
                themeByID[local.id] = local
            }
        }

        for theme in scanWallBuddyThemes() {
            themeByID[theme.id] = theme
        }

        let themes = themeByID.values.sorted {
            if $0.isCurated != $1.isCurated { return $0.isCurated }
            if $0.origin != $1.origin { return $0.origin == .wallBuddy }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        let curatedCount = themes.filter(\.isCurated).count
        let localCount = themes.filter { $0.isInstalled && $0.origin != .wallBuddy }.count
        let wallBuddyCount = themes.filter { $0.origin == .wallBuddy }.count
        let wallBuddyPath = wallBuddyBundle.path
        let message: String
        if wallBuddyCount > 0 {
            message = "\(themes.count) themes ready · \(wallBuddyCount) local image source\(wallBuddyCount == 1 ? "" : "s") found"
        } else {
            message = "\(themes.count) bundled and local themes ready"
        }

        return ThemeLibraryResult(
            themes: themes,
            curatedCount: curatedCount,
            localCount: localCount,
            wallBuddyCount: wallBuddyCount,
            managedPath: managedThemesDirectory.path,
            wallBuddyPath: wallBuddyPath,
            message: message
        )
    }
}
