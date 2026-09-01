import Foundation
import Darwin

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

    private static var bundledDockDoorLauncherDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("CodexThemedLauncherTemplate", isDirectory: true)
    }

    private static var installedRuntimeDirectory: URL {
        homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("codex-dream-skin-studio", isDirectory: true)
    }

    private static let dockDoorLauncherBundleIdentifier = "com.codexthemes.themed-codex-launcher"

    private static var dockDoorLauncherCandidates: [URL] {
        [
            URL(fileURLWithPath: "/Applications/Codex Themed.app", isDirectory: true),
            homeDirectory
                .appendingPathComponent("Applications", isDirectory: true)
                .appendingPathComponent("Codex Themed.app", isDirectory: true)
        ]
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

        let wallBuddyThemes = scanWallBuddyThemes()
        for theme in wallBuddyThemes {
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

    @discardableResult
    static func installBundledRuntimeIfNeeded() -> Bool {
        let fileManager = FileManager.default
        guard let bundledRuntimeDirectory,
              fileManager.fileExists(atPath: bundledRuntimeDirectory.appendingPathComponent("scripts/switch-theme-macos.sh").path)
        else {
            return false
        }

        var changed = false
        if runtimeNeedsInstallation(bundledRuntimeDirectory: bundledRuntimeDirectory) {
            changed = installRuntimeAtomically(from: bundledRuntimeDirectory)
        }

        // The launcher is intentionally installed separately from the runtime.
        // This lets a Sparkle update repair an older DockDoor pin even when the
        // managed runtime is already at the same version.
        if installBundledDockDoorLauncher() {
            changed = true
        }

        // DockDoor can re-identify the helper as the official Codex process
        // after a shortcut is removed and re-pinned. Repair that mapping while
        // the bundled helper is being installed so the fix carries through
        // Sparkle updates to every Mac using DockDoor Pro.
        if DockDoorIntegrationService.repairIfNeeded() {
            changed = true
        }

        if changed {
            refreshInstalledPersistenceMonitor()
        }
        return changed
    }

    private static func runtimeNeedsInstallation(bundledRuntimeDirectory: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: installedRuntimeDirectory.path) else {
            return true
        }
        guard let bundledVersion = runtimeVersion(at: bundledRuntimeDirectory),
              let installedVersion = runtimeVersion(at: installedRuntimeDirectory)
        else {
            // Preserve an existing runtime whose provenance/version cannot be
            // established. The launcher can still be refreshed independently.
            return false
        }
        return isVersion(bundledVersion, newerThan: installedVersion)
    }

    private static func runtimeVersion(at directory: URL) -> [Int]? {
        let versionURL = directory.appendingPathComponent("VERSION")
        guard let raw = try? String(contentsOf: versionURL, encoding: .utf8) else {
            return nil
        }
        let components = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
        guard !components.isEmpty else { return nil }
        let values = components.compactMap { Int($0) }
        return values.count == components.count ? values : nil
    }

    private static func isVersion(_ candidate: [Int], newerThan installed: [Int]) -> Bool {
        let count = max(candidate.count, installed.count)
        for index in 0..<count {
            let candidateValue = index < candidate.count ? candidate[index] : 0
            let installedValue = index < installed.count ? installed[index] : 0
            if candidateValue != installedValue {
                return candidateValue > installedValue
            }
        }
        return false
    }

    private static func installRuntimeAtomically(from bundledRuntimeDirectory: URL) -> Bool {
        let fileManager = FileManager.default
        let codexDirectory = installedRuntimeDirectory.deletingLastPathComponent()
        let stagingDirectory = codexDirectory.appendingPathComponent(
            ".codex-dream-skin-studio.installing-\(UUID().uuidString)",
            isDirectory: true
        )
        let backupDirectory = codexDirectory.appendingPathComponent(
            ".codex-dream-skin-studio.previous-\(UUID().uuidString)",
            isDirectory: true
        )
        var movedExisting = false

        do {
            try fileManager.createDirectory(
                at: codexDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.copyItem(at: bundledRuntimeDirectory, to: stagingDirectory)
            let stagedScript = stagingDirectory.appendingPathComponent("scripts/switch-theme-macos.sh")
            guard fileManager.isReadableFile(atPath: stagedScript.path) else {
                try? fileManager.removeItem(at: stagingDirectory)
                return false
            }
            if fileManager.fileExists(atPath: installedRuntimeDirectory.path) {
                try fileManager.moveItem(at: installedRuntimeDirectory, to: backupDirectory)
                movedExisting = true
            }
            try fileManager.moveItem(at: stagingDirectory, to: installedRuntimeDirectory)
            normalizeRuntimePermissions(at: installedRuntimeDirectory)
            if movedExisting {
                try? fileManager.removeItem(at: backupDirectory)
            }
            return true
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            if movedExisting,
               !fileManager.fileExists(atPath: installedRuntimeDirectory.path),
               fileManager.fileExists(atPath: backupDirectory.path) {
                try? fileManager.moveItem(at: backupDirectory, to: installedRuntimeDirectory)
            }
            return false
        }
    }

    private static func installBundledDockDoorLauncher() -> Bool {
        let fileManager = FileManager.default
        guard let source = bundledDockDoorLauncherDirectory,
              isManagedDockDoorLauncher(source),
              fileManager.fileExists(atPath: source.appendingPathComponent("Contents/MacOS/CodexThemedLauncher").path)
        else {
            return false
        }

        let existingDestination = dockDoorLauncherCandidates.first(where: isManagedDockDoorLauncher)
        let destination: URL
        if let existingDestination {
            destination = existingDestination
        } else if let writableDestination = dockDoorLauncherCandidates.first(where: { candidate in
            !fileManager.fileExists(atPath: candidate.path) && writableParent(of: candidate)
        }) {
            destination = writableDestination
        } else {
            // Never overwrite an unrelated app with the familiar DockDoor name.
            return false
        }

        let sourceInfo = source.appendingPathComponent("Contents/Info.plist")
        let destinationInfo = destination.appendingPathComponent("Contents/Info.plist")
        let sourceVersion = bundleValue("CFBundleVersion", at: sourceInfo)
        let destinationVersion = bundleValue("CFBundleVersion", at: destinationInfo)
        let sourceExecutable = source.appendingPathComponent("Contents/MacOS/CodexThemedLauncher")
        let destinationExecutable = destination.appendingPathComponent("Contents/MacOS/CodexThemedLauncher")
        if fileManager.fileExists(atPath: destination.path),
           sourceVersion == destinationVersion,
           fileManager.contentsEqual(atPath: sourceExecutable.path, andPath: destinationExecutable.path) {
            return false
        }

        let parent = destination.deletingLastPathComponent()
        let staging = parent.appendingPathComponent(
            ".Codex Themed.app.installing-\(UUID().uuidString)",
            isDirectory: true
        )
        let backup = parent.appendingPathComponent(
            ".Codex Themed.app.previous-\(UUID().uuidString)",
            isDirectory: true
        )
        var movedExisting = false

        do {
            try fileManager.copyItem(at: source, to: staging)
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: staging.appendingPathComponent("Contents/MacOS/CodexThemedLauncher").path
            )
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.moveItem(at: destination, to: backup)
                movedExisting = true
            }
            try fileManager.moveItem(at: staging, to: destination)
            if movedExisting {
                try? fileManager.removeItem(at: backup)
            }
            return true
        } catch {
            try? fileManager.removeItem(at: staging)
            if movedExisting,
               !fileManager.fileExists(atPath: destination.path),
               fileManager.fileExists(atPath: backup.path) {
                try? fileManager.moveItem(at: backup, to: destination)
            }
            return false
        }
    }

    private static func writableParent(of url: URL) -> Bool {
        let fileManager = FileManager.default
        let parent = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path), parent.path == homeDirectory.appendingPathComponent("Applications").path {
            try? fileManager.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
        }
        return fileManager.isWritableFile(atPath: parent.path)
    }

    private static func isManagedDockDoorLauncher(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path),
              bundleValue("CFBundleIdentifier", at: url.appendingPathComponent("Contents/Info.plist")) == dockDoorLauncherBundleIdentifier
        else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/MacOS/CodexThemedLauncher").path)
    }

    private static func bundleValue(_ key: String, at infoURL: URL) -> String? {
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return nil
        }
        return plist[key] as? String
    }

    private static func refreshInstalledPersistenceMonitor() {
        let agent = homeDirectory
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("com.codexthemes.theme-monitor.plist")
        guard FileManager.default.fileExists(atPath: agent.path) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kickstart", "-k", "gui/\(getuid())/com.codexthemes.theme-monitor"]
        try? process.run()
        process.waitUntilExit()
    }

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

    private static func isLocalOnlyTheme(at directory: URL) -> Bool {
        boolValue(catalogMetadata(in: directory), key: "localOnly")
    }

    private static func localOnlyThemeNeedsRefresh(source: URL, destination: URL) -> Bool {
        let sourceImageURL = stringValue(catalogMetadata(in: source), key: "imageURL")
        let destinationImageURL = stringValue(catalogMetadata(in: destination), key: "imageURL")
        return sourceImageURL.isEmpty || sourceImageURL != destinationImageURL
    }

    private static func refreshManagedThemeAtomically(from source: URL, to destination: URL, id: String) -> Bool {
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

    private static func normalizeRuntimePermissions(at root: URL) {
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

    static func importTheme(from source: URL) throws -> String {
        let fileManager = FileManager.default
        let source = source.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ThemeImportError.invalidSource("Choose an extracted theme folder.")
        }

        let manifestURL = source.appendingPathComponent("theme.json")
        guard let manifestData = try? Data(contentsOf: manifestURL), manifestData.count <= 256 * 1024 else {
            throw ThemeImportError.invalidSource("The folder must contain a theme.json no larger than 256 KB.")
        }
        guard let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any] else {
            throw ThemeImportError.invalidSource("theme.json is not valid JSON.")
        }

        let id = stringValue(manifest, key: "id")
        guard isSafeThemeID(id) else {
            throw ThemeImportError.invalidSource("Theme ids may contain letters, numbers, dots, underscores, and hyphens.")
        }
        guard numberValue(manifest, key: "schemaVersion") == 1 else {
            throw ThemeImportError.invalidSource("Only schemaVersion 1 themes are supported.")
        }

        let imageName = stringValue(manifest, key: "image")
        guard isSafeFileName(imageName), supportedImageExtensions.contains(URL(fileURLWithPath: imageName).pathExtension.lowercased()) else {
            throw ThemeImportError.invalidSource("Theme image must be a local JPG, PNG, WebP, or HEIC filename.")
        }
        let imageURL = source.appendingPathComponent(imageName)
        guard fileManager.fileExists(atPath: imageURL.path), regularFile(at: imageURL) else {
            throw ThemeImportError.invalidSource("The referenced theme image is missing.")
        }
        guard (try? imageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int.init).map({ $0 <= 16 * 1024 * 1024 }) == true else {
            throw ThemeImportError.invalidSource("The theme image exceeds the 16 MB limit.")
        }

        let destinationRoot = managedThemesDirectory
        try fileManager.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        let destination = destinationRoot.appendingPathComponent(id, isDirectory: true)
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw ThemeImportError.invalidSource("A theme with this id is already installed.")
        }

        let previewName = stringValue(manifest, key: "preview", fallback: imageName)
        var names = ["theme.json", imageName]
        if isSafeFileName(previewName), fileManager.fileExists(atPath: source.appendingPathComponent(previewName).path) {
            names.append(previewName)
        }
        for optionalName in ["README.md", "theme.css", "catalog.json", "LICENSE.txt"] where fileManager.fileExists(atPath: source.appendingPathComponent(optionalName).path) {
            names.append(optionalName)
        }
        names = Array(Set(names))

        let stage = destinationRoot.appendingPathComponent(".\(id).importing-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: stage) }

        for name in names {
            let origin = source.appendingPathComponent(name)
            guard regularFile(at: origin) else {
                throw ThemeImportError.invalidSource("Theme entries must be regular files.")
            }
            try fileManager.copyItem(at: origin, to: stage.appendingPathComponent(name))
        }

        try fileManager.moveItem(at: stage, to: destination)
        return "Imported \(stringValue(manifest, key: "name", fallback: id)) into the local library."
    }

    private static func scanManagedThemes() -> [Theme] {
        let fileManager = FileManager.default
        guard let entryNames = try? fileManager.contentsOfDirectory(atPath: managedThemesDirectory.path) else {
            return []
        }

        return entryNames.filter { !$0.hasPrefix(".") }.compactMap { entryName in
            let directory = managedThemesDirectory.appendingPathComponent(entryName, isDirectory: true)
            guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true,
                  values.isSymbolicLink != true
            else { return nil }
            return parseThemeDirectory(directory, origin: .local)
        }
    }

    private static func scanBundledThemes() -> [Theme] {
        let fileManager = FileManager.default
        guard let bundledThemesDirectory,
              let entryNames = try? fileManager.contentsOfDirectory(atPath: bundledThemesDirectory.path)
        else {
            return []
        }

        return entryNames.filter { !$0.hasPrefix(".") }.compactMap { entryName in
            let directory = bundledThemesDirectory.appendingPathComponent(entryName, isDirectory: true)
            guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true,
                  values.isSymbolicLink != true
            else { return nil }
            return parseThemeDirectory(directory, origin: .curated)
        }
    }

    private static func parseThemeDirectory(_ directory: URL, origin: ThemeOrigin) -> Theme? {
        let manifestURL = directory.appendingPathComponent("theme.json")
        guard let data = try? Data(contentsOf: manifestURL),
              data.count <= 256 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let id = stringValue(object, key: "id")
        guard isSafeThemeID(id) else { return nil }
        let imageName = stringValue(object, key: "image", fallback: "background.jpg")
        guard isSafeFileName(imageName) else { return nil }
        let imageURL = directory.appendingPathComponent(imageName)
        guard regularFile(at: imageURL) else { return nil }

        let previewName = stringValue(object, key: "preview", fallback: imageName)
        let previewURL = isSafeFileName(previewName) && regularFile(at: directory.appendingPathComponent(previewName))
            ? directory.appendingPathComponent(previewName)
            : imageURL
        let colors = object["colors"] as? [String: Any] ?? [:]
        let art = object["art"] as? [String: Any] ?? [:]
        let catalog = catalogMetadata(in: directory)
        let category = stringValue(
            catalog,
            key: "category",
            fallback: stringValue(object, key: "category", fallback: stringValue(object, key: "collection", fallback: "Local"))
        )
        let sourceURL = stringValue(catalog, key: "sourceURL", fallback: stringValue(object, key: "promoUrl"))
        let rightsSummary = stringValue(catalog, key: "rightsStatus")
        let aiGenerated = optionalBoolValue(catalog, key: "aiGenerated")
        let hasVerifiedProvenance = regularFile(at: directory.appendingPathComponent("LICENSE.txt"))
            && aiGenerated == false
            && !sourceURL.isEmpty
            && (rightsSummary.localizedCaseInsensitiveContains("public domain") || rightsSummary.localizedCaseInsensitiveContains("cc0"))

        return Theme(
            id: id,
            name: stringValue(object, key: "name", fallback: id),
            author: stringValue(catalog, key: "artist", fallback: stringValue(object, key: "author", fallback: "Creator not recorded")),
            description: stringValue(catalog, key: "summary", fallback: stringValue(object, key: "description", fallback: stringValue(object, key: "tagline", fallback: "A locally managed Codex theme."))),
            category: category,
            collection: stringValue(catalog, key: "collection", fallback: stringValue(object, key: "collection", fallback: "Local library")),
            appearance: stringValue(object, key: "appearance", fallback: "auto"),
            palette: ThemePalette(
                background: stringValue(colors, key: "background", fallback: ThemePalette.fallback.background),
                panel: stringValue(colors, key: "panel", fallback: ThemePalette.fallback.panel),
                panelAlt: stringValue(colors, key: "panelAlt", fallback: ThemePalette.fallback.panelAlt),
                accent: stringValue(colors, key: "accent", fallback: ThemePalette.fallback.accent),
                accentAlt: stringValue(colors, key: "accentAlt", fallback: ThemePalette.fallback.accentAlt),
                secondary: stringValue(colors, key: "secondary", fallback: ThemePalette.fallback.secondary),
                highlight: stringValue(colors, key: "highlight", fallback: ThemePalette.fallback.highlight),
                text: stringValue(colors, key: "text", fallback: ThemePalette.fallback.text),
                muted: stringValue(colors, key: "muted", fallback: ThemePalette.fallback.muted),
                line: stringValue(colors, key: "line", fallback: ThemePalette.fallback.line)
            ),
            imagePath: imageURL.path,
            previewPath: previewURL.path,
            origin: origin,
            isInstalled: true,
            isCurated: hasVerifiedProvenance,
            isFavorite: false,
            focusX: numberValue(art, key: "focusX", fallback: 0.5),
            focusY: numberValue(art, key: "focusY", fallback: 0.5),
            safeArea: stringValue(art, key: "safeArea", fallback: "auto"),
            taskMode: stringValue(art, key: "taskMode", fallback: "auto"),
            sourceURL: sourceURL.isEmpty ? nil : sourceURL,
            rightsSummary: rightsSummary.isEmpty ? nil : rightsSummary,
            institution: stringValue(catalog, key: "institution").nilIfEmpty,
            isAIGenerated: aiGenerated
        )
    }

    private static func catalogMetadata(in directory: URL) -> [String: Any] {
        let url = directory.appendingPathComponent("catalog.json")
        guard regularFile(at: url),
              let data = try? Data(contentsOf: url),
              data.count <= 64 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              numberValue(object, key: "schemaVersion") == 1
        else {
            return [:]
        }
        return object
    }

    private static func scanWallBuddyThemes() -> [Theme] {
        let fileManager = FileManager.default
        let bundle = wallBuddyBundle
        let roots = [
            bundle.appendingPathComponent("Contents/Resources", isDirectory: true),
            bundle.deletingLastPathComponent().appendingPathComponent("assets", isDirectory: true)
        ]
        var candidates: [URL] = []
        for root in roots {
            guard let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { continue }
            candidates.append(contentsOf: entries.filter { url in
                guard supportedImageExtensions.contains(url.pathExtension.lowercased()), regularFile(at: url) else { return false }
                let name = url.deletingPathExtension().lastPathComponent.lowercased()
                if name.contains("icon") || name.contains("installer") || name.contains("pokopia") { return false }
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return size > 10_000
            })
        }

        var seen = Set<String>()
        return candidates.sorted { $0.path < $1.path }.compactMap { url in
            guard seen.insert(url.path).inserted else { return nil }
            let slug = slugify(url.deletingPathExtension().lastPathComponent)
            return Theme(
                id: "wallbuddy-\(slug)",
                name: "Local · \(displayName(url.deletingPathExtension().lastPathComponent))",
                author: "Local source",
                description: "A local visual source discovered on this Mac.",
                category: "Local source",
                collection: "Local source",
                appearance: "dark",
                palette: ThemePalette(
                    background: "#05060A",
                    panel: "#10131B",
                    panelAlt: "#1B2030",
                    accent: "#D946EF",
                    accentAlt: "#67E8F9",
                    secondary: "#31517A",
                    highlight: "#D8B4FE",
                    text: "#F9FAFB",
                    muted: "#A7B0C0",
                    line: "rgba(217,70,239,0.34)"
                ),
                imagePath: url.path,
                previewPath: url.path,
                origin: .wallBuddy,
                isInstalled: false,
                isCurated: false,
                isFavorite: false,
                focusX: 0.5,
                focusY: 0.5,
                safeArea: "left",
                taskMode: "ambient"
            )
        }
    }

    private static func regularFile(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]) else { return false }
        return values.isRegularFile == true
    }

    private static func isSafeThemeID(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= 80, id.first?.isLetter == true || id.first?.isNumber == true else { return false }
        return id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-" }
    }

    private static func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty && URL(fileURLWithPath: name).lastPathComponent == name && !name.contains("/") && !name.contains("\\")
    }

    private static func stringValue(_ object: [String: Any], key: String, fallback: String = "") -> String {
        object[key] as? String ?? fallback
    }

    private static func numberValue(_ object: [String: Any], key: String, fallback: Double = 0) -> Double {
        if let number = object[key] as? NSNumber { return number.doubleValue }
        return fallback
    }

    private static func boolValue(_ object: [String: Any], key: String, fallback: Bool = false) -> Bool {
        if let value = object[key] as? Bool { return value }
        if let number = object[key] as? NSNumber { return number.boolValue }
        return fallback
    }

    private static func optionalBoolValue(_ object: [String: Any], key: String) -> Bool? {
        if let value = object[key] as? Bool { return value }
        if let number = object[key] as? NSNumber { return number.boolValue }
        return nil
    }

    private static func slugify(_ value: String) -> String {
        let lowered = value.lowercased().map { character in
            character.isLetter || character.isNumber ? String(character) : "-"
        }.joined()
        return lowered.split(separator: "-").joined(separator: "-").prefix(48).description
    }

    private static func displayName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

enum ThemeImportError: LocalizedError {
    case invalidSource(String)

    var errorDescription: String? {
        switch self {
        case .invalidSource(let message): message
        }
    }
}
