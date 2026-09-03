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

    static func loadCachedSynchronously() -> ThemeLibraryResult? {
        ThemeLibraryCache.load()
    }

    static func loadSynchronously() -> ThemeLibraryResult {
        _ = installBundledRuntimeIfNeeded()

        let bundledThemes = scanBundledThemes()
        let localThemes = scanManagedThemes()
        // Catalogs are user-editable inputs. A duplicate id should be
        // deterministic rather than crashing startup inside
        // Dictionary(uniqueKeysWithValues:).
        var themeByID: [String: Theme] = [:]
        for theme in bundledThemes {
            themeByID[theme.id] = theme
        }

        for local in localThemes {
            if let bundled = themeByID[local.id] {
                themeByID[local.id] = bundled.mergingLocal(local)
            } else {
                themeByID[local.id] = local
            }
        }

        let themes = themeByID.values.sorted {
            if $0.isCurated != $1.isCurated { return $0.isCurated }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        let curatedCount = themes.filter(\.isCurated).count
        let localCount = themes.filter(\.isInstalled).count

        let result = ThemeLibraryResult(
            themes: themes,
            curatedCount: curatedCount,
            localCount: localCount,
            managedPath: managedThemesDirectory.path,
            message: "\(themes.count) bundled and local themes ready"
        )
        ThemeLibraryCache.save(result)
        return result
    }
}
