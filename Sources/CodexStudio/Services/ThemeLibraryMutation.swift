// Bundled theme seeding, refresh, and managed-runtime permissions.

import Foundation

extension ThemeLibraryService {

    @discardableResult
    static func installBundledThemeIfNeeded(_ id: String) -> Bool {
        let fileManager = FileManager.default
        guard isSafeThemeID(id),
              let bundledThemesDirectory
        else {
            return false
        }

        let destination = managedThemesDirectory.appendingPathComponent(id, isDirectory: true)
        let source = bundledThemesDirectory.appendingPathComponent(id, isDirectory: true)
        guard (try? source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]))
            .map({ $0.isDirectory == true && $0.isSymbolicLink != true }) == true,
              parseThemeDirectory(source, origin: .curated) != nil
        else {
            return false
        }

        if fileManager.fileExists(atPath: destination.appendingPathComponent("theme.json").path) {
            // A previous build may have installed an older local copy under
            // the same id. Apple wallpaper packs are local-only and are
            // refreshed atomically so applying one always uses the official
            // bundled image rather than a stale managed asset.
            if isLocalOnlyTheme(at: source) && localOnlyThemeNeedsRefresh(source: source, destination: destination) {
                return refreshManagedThemeAtomically(from: source, to: destination, id: id)
            }
            return true
        }
        guard !fileManager.fileExists(atPath: destination.path) else { return false }

        do {
            try fileManager.createDirectory(
                at: managedThemesDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let stagingDirectory = managedThemesDirectory.appendingPathComponent(
                ".\(id).bundled-\(UUID().uuidString)",
                isDirectory: true
            )
            defer { try? fileManager.removeItem(at: stagingDirectory) }
            try fileManager.copyItem(at: source, to: stagingDirectory)
            guard parseThemeDirectory(stagingDirectory, origin: .local) != nil,
                  !fileManager.fileExists(atPath: destination.path)
            else {
                return false
            }
            try fileManager.moveItem(at: stagingDirectory, to: destination)
            return true
        } catch {
            return false
        }
    }

    static func isLocalOnlyTheme(at directory: URL) -> Bool {
        boolValue(catalogMetadata(in: directory), key: "localOnly")
    }

    static func localOnlyThemeNeedsRefresh(source: URL, destination: URL) -> Bool {
        let sourceImageURL = stringValue(catalogMetadata(in: source), key: "imageURL")
        let destinationImageURL = stringValue(catalogMetadata(in: destination), key: "imageURL")
        return sourceImageURL.isEmpty || sourceImageURL != destinationImageURL
    }

    static func refreshManagedThemeAtomically(from source: URL, to destination: URL, id: String) -> Bool {
        let fileManager = FileManager.default
        let codexDirectory = managedThemesDirectory
        let stagingDirectory = codexDirectory.appendingPathComponent(
            ".(id).bundled-(UUID().uuidString)",
            isDirectory: true
        )
        let backupDirectory = codexDirectory.appendingPathComponent(
            ".(id).previous-(UUID().uuidString)",
            isDirectory: true
        )
        var movedExisting = false

        do {
            guard (try? destination.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]))
                .map({ $0.isDirectory == true && $0.isSymbolicLink != true }) == true
            else {
                return false
            }
            try fileManager.createDirectory(
                at: codexDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.copyItem(at: source, to: stagingDirectory)
            guard parseThemeDirectory(stagingDirectory, origin: .local) != nil else {
                try? fileManager.removeItem(at: stagingDirectory)
                return false
            }
            try fileManager.moveItem(at: destination, to: backupDirectory)
            movedExisting = true
            try fileManager.moveItem(at: stagingDirectory, to: destination)
            try? fileManager.removeItem(at: backupDirectory)
            return true
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            if movedExisting,
               !fileManager.fileExists(atPath: destination.path),
               fileManager.fileExists(atPath: backupDirectory.path) {
                try? fileManager.moveItem(at: backupDirectory, to: destination)
            }
            return false
        }
    }

    @discardableResult
    static func seedBundledThemesIfNeeded() -> Int {
        let fileManager = FileManager.default
        guard let bundledThemesDirectory,
              let entryNames = try? fileManager.contentsOfDirectory(atPath: bundledThemesDirectory.path)
        else {
            return 0
        }
        let entries = entryNames
            .filter { !$0.hasPrefix(".") }
            .map { bundledThemesDirectory.appendingPathComponent($0, isDirectory: true) }

        do {
            try fileManager.createDirectory(
                at: managedThemesDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: managedThemesDirectory.path)
        } catch {
            return 0
        }

        var seededCount = 0
        for source in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let id = source.lastPathComponent
            guard isSafeThemeID(id) else { continue }
            let manifestURL = source.appendingPathComponent("theme.json")
            guard let manifestData = try? Data(contentsOf: manifestURL),
                  manifestData.count <= 256 * 1024,
                  let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
                  stringValue(manifest, key: "id") == id,
                  numberValue(manifest, key: "schemaVersion") == 1
            else {
                continue
            }

            let destination = managedThemesDirectory.appendingPathComponent(id, isDirectory: true)
            guard !fileManager.fileExists(atPath: destination.path) else { continue }

            let stagingDirectory = managedThemesDirectory.appendingPathComponent(
                ".\(id).bundled-\(UUID().uuidString)",
                isDirectory: true
            )
            do {
                try fileManager.copyItem(at: source, to: stagingDirectory)
                guard parseThemeDirectory(stagingDirectory, origin: .local) != nil else {
                    try? fileManager.removeItem(at: stagingDirectory)
                    continue
                }
                guard !fileManager.fileExists(atPath: destination.path) else {
                    try? fileManager.removeItem(at: stagingDirectory)
                    continue
                }
                try fileManager.moveItem(at: stagingDirectory, to: destination)
                seededCount += 1
            } catch {
                try? fileManager.removeItem(at: stagingDirectory)
            }
        }
        return seededCount
    }

    static func normalizeRuntimePermissions(at root: URL) {
        let fileManager = FileManager.default
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            let permissions = isDirectory || url.pathExtension.lowercased() == "sh" ? 0o700 : 0o600
            try? fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
        }
    }


}
