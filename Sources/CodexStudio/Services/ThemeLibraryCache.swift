import Foundation

/// Keeps the last verified catalog metadata available for the first frame of
/// the studio. Artwork is still resolved from the current bundle or managed
/// library, so moving the app does not leave the cache pointing at an old
/// staged path. A fresh scan replaces the snapshot in the background.
struct ThemeLibraryCache: Sendable {
    private static let schemaVersion = 1
    private static let fileName = "library-index.json"

    private struct Snapshot: Codable, Sendable {
        let schemaVersion: Int
        let themes: [Theme]
        let createdAt: Date
    }

    static var url: URL {
        ThemeLibraryService.homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexStudio", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func load() -> ThemeLibraryResult? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.schemaVersion == schemaVersion,
              !snapshot.themes.isEmpty
        else {
            return nil
        }

        let themes = snapshot.themes.map(rebased)
        return ThemeLibraryResult(
            themes: themes,
            curatedCount: themes.filter(\.isCurated).count,
            localCount: themes.filter(\.isInstalled).count,
            managedPath: ThemeLibraryService.managedThemesDirectory.path,
            message: "Cached local index · refreshing in the background"
        )
    }

    static func save(_ result: ThemeLibraryResult) {
        let snapshot = Snapshot(
            schemaVersion: schemaVersion,
            themes: result.themes,
            createdAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }

        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try data.write(to: url, options: [.atomic])
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            // The catalog is an optimization. A failed cache write must never
            // make an otherwise-valid local library unavailable.
        }
    }

    private static func rebased(_ theme: Theme) -> Theme {
        guard theme.origin == .curated,
              let bundledThemesDirectory = ThemeLibraryService.bundledThemesDirectory
        else {
            return theme
        }

        let directory = bundledThemesDirectory.appendingPathComponent(theme.id, isDirectory: true)
        var current = theme
        if let imagePath = theme.imagePath {
            let cachedURL = URL(fileURLWithPath: imagePath)
            if !ThemeLibraryService.regularFile(at: cachedURL) {
                let imageURL = directory.appendingPathComponent(cachedURL.lastPathComponent)
                if ThemeLibraryService.regularFile(at: imageURL) {
                    current.imagePath = imageURL.path
                }
            }
        }
        if let previewPath = theme.previewPath {
            let cachedURL = URL(fileURLWithPath: previewPath)
            if !ThemeLibraryService.regularFile(at: cachedURL) {
                let previewURL = directory.appendingPathComponent(cachedURL.lastPathComponent)
                if ThemeLibraryService.regularFile(at: previewURL) {
                    current.previewPath = previewURL.path
                }
            }
        }
        return current
    }
}
