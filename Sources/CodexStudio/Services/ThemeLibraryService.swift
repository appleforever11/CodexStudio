import Foundation

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

    private static var installedRuntimeDirectory: URL {
        homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("codex-dream-skin-studio", isDirectory: true)
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
        _ = seedBundledThemesIfNeeded()

        let localThemes = scanManagedThemes()
        var themeByID = Dictionary(uniqueKeysWithValues: localThemes.map { ($0.id, $0) })

        for curated in ThemeCatalog.curated {
            if let local = themeByID[curated.id] {
                themeByID[curated.id] = curated.mergingLocal(local)
            } else {
                themeByID[curated.id] = curated
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
        let localCount = themes.filter { $0.origin == .local }.count
        let wallBuddyCount = themes.filter { $0.origin == .wallBuddy }.count
        let wallBuddyPath = wallBuddyBundle.path
        let message: String
        if wallBuddyCount > 0 {
            message = "\(themes.count) themes ready · \(wallBuddyCount) WallBuddy asset\(wallBuddyCount == 1 ? "" : "s") found"
        } else {
            message = "\(themes.count) themes ready · local library connected"
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
              fileManager.fileExists(atPath: bundledRuntimeDirectory.appendingPathComponent("scripts/switch-theme-macos.sh").path),
              !fileManager.fileExists(atPath: installedRuntimeDirectory.path)
        else {
            return false
        }

        let codexDirectory = installedRuntimeDirectory.deletingLastPathComponent()
        let stagingDirectory = codexDirectory.appendingPathComponent(
            ".codex-dream-skin-studio.installing-\(UUID().uuidString)",
            isDirectory: true
        )

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
            guard !fileManager.fileExists(atPath: installedRuntimeDirectory.path) else {
                try? fileManager.removeItem(at: stagingDirectory)
                return false
            }
            try fileManager.moveItem(at: stagingDirectory, to: installedRuntimeDirectory)
            normalizeRuntimePermissions(at: installedRuntimeDirectory)
            return true
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            return false
        }
    }

    @discardableResult
    static func seedBundledThemesIfNeeded() -> Int {
        let fileManager = FileManager.default
        guard let bundledThemesDirectory,
              let entries = try? fileManager.contentsOfDirectory(
                at: bundledThemesDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              )
        else {
            return 0
        }

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
        for optionalName in ["README.md", "theme.css"] where fileManager.fileExists(atPath: source.appendingPathComponent(optionalName).path) {
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
        guard let entries = try? fileManager.contentsOfDirectory(
            at: managedThemesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries.compactMap { directory in
            guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            return parseThemeDirectory(directory, origin: .local)
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
        let category = stringValue(object, key: "category", fallback: stringValue(object, key: "collection", fallback: "Local"))

        return Theme(
            id: id,
            name: stringValue(object, key: "name", fallback: id),
            author: stringValue(object, key: "author", fallback: "Local theme"),
            description: stringValue(object, key: "description", fallback: stringValue(object, key: "tagline", fallback: "A locally managed Codex theme.")),
            category: category,
            collection: stringValue(object, key: "collection", fallback: "Local library"),
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
            isCurated: false,
            isFavorite: false,
            focusX: numberValue(art, key: "focusX", fallback: 0.5),
            focusY: numberValue(art, key: "focusY", fallback: 0.5),
            safeArea: stringValue(art, key: "safeArea", fallback: "auto"),
            taskMode: stringValue(art, key: "taskMode", fallback: "auto")
        )
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
                name: "WallBuddy · \(displayName(url.deletingPathExtension().lastPathComponent))",
                author: "WallBuddy",
                description: "A local visual source discovered from the WallBuddy workspace.",
                category: "WallBuddy",
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

enum ThemeImportError: LocalizedError {
    case invalidSource(String)

    var errorDescription: String? {
        switch self {
        case .invalidSource(let message): message
        }
    }
}
