import Foundation

extension ThemeLibraryService {
    /// Apple artwork stays on this Mac when a distributable update replaces
    /// a development bundle that included the local-only wallpaper shelves.
    static var localThemePacksDirectory: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/CodexStudio/ThemePacks", isDirectory: true)
    }

    static func localThemePack(
        _ id: String,
        in root: URL = localThemePacksDirectory
    ) -> Theme? {
        guard isSafeThemeID(id) else { return nil }
        let directory = root.appendingPathComponent(id, isDirectory: true)
        guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink != true,
              isLocalOnlyTheme(at: directory),
              regularFile(at: directory.appendingPathComponent("LICENSE.txt")),
              let theme = parseThemeDirectory(directory, origin: .curated),
              theme.id == id
        else { return nil }
        return theme
    }

    static func scanLocalThemePacks(in root: URL = localThemePacksDirectory) -> [Theme] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: root.path) else { return [] }
        return names.sorted().filter { !$0.hasPrefix(".") }.compactMap { localThemePack($0, in: root) }
    }

    static func availableThemePackDirectory(_ id: String) -> URL? {
        guard isSafeThemeID(id) else { return nil }
        if let bundled = bundledThemesDirectory?.appendingPathComponent(id, isDirectory: true),
           let values = try? bundled.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
           values.isDirectory == true, values.isSymbolicLink != true,
           parseThemeDirectory(bundled, origin: .curated)?.id == id {
            return bundled
        }
        guard localThemePack(id) != nil else { return nil }
        return localThemePacksDirectory.appendingPathComponent(id, isDirectory: true)
    }
}
