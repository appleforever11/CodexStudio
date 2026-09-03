// Theme discovery, manifest parsing, provenance, and local image sources.

import Foundation

extension ThemeLibraryService {

    static func scanManagedThemes() -> [Theme] {
        let fileManager = FileManager.default
        guard let entryNames = try? fileManager.contentsOfDirectory(atPath: managedThemesDirectory.path) else {
            return []
        }

        return entryNames.sorted().filter { !$0.hasPrefix(".") }.compactMap { entryName in
            let directory = managedThemesDirectory.appendingPathComponent(entryName, isDirectory: true)
            guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true,
                  values.isSymbolicLink != true
            else { return nil }
            return parseThemeDirectory(directory, origin: .local)
        }
    }

    static func scanBundledThemes() -> [Theme] {
        let fileManager = FileManager.default
        guard let bundledThemesDirectory,
              let entryNames = try? fileManager.contentsOfDirectory(atPath: bundledThemesDirectory.path)
        else {
            return []
        }

        return entryNames.sorted().filter { !$0.hasPrefix(".") }.compactMap { entryName in
            let directory = bundledThemesDirectory.appendingPathComponent(entryName, isDirectory: true)
            guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true,
                  values.isSymbolicLink != true
            else { return nil }
            return parseThemeDirectory(directory, origin: .curated)
        }
    }

    static func parseThemeDirectory(_ directory: URL, origin: ThemeOrigin) -> Theme? {
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
        let platformVersion = stringValue(catalog, key: "platformVersion").nilIfEmpty
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
            isAIGenerated: aiGenerated,
            platformVersion: platformVersion
        )
    }

    static func catalogMetadata(in directory: URL) -> [String: Any] {
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

    static func scanWallBuddyThemes() -> [Theme] {
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

    static func regularFile(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]) else { return false }
        return values.isRegularFile == true
    }

    static func isSafeThemeID(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= 80, id.first?.isLetter == true || id.first?.isNumber == true else { return false }
        return id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-" }
    }

    static func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty && URL(fileURLWithPath: name).lastPathComponent == name && !name.contains("/") && !name.contains("\\")
    }

    static func stringValue(_ object: [String: Any], key: String, fallback: String = "") -> String {
        object[key] as? String ?? fallback
    }

    static func numberValue(_ object: [String: Any], key: String, fallback: Double = 0) -> Double {
        if let number = object[key] as? NSNumber { return number.doubleValue }
        return fallback
    }

    static func boolValue(_ object: [String: Any], key: String, fallback: Bool = false) -> Bool {
        if let value = object[key] as? Bool { return value }
        if let number = object[key] as? NSNumber { return number.boolValue }
        return fallback
    }

    static func optionalBoolValue(_ object: [String: Any], key: String) -> Bool? {
        if let value = object[key] as? Bool { return value }
        if let number = object[key] as? NSNumber { return number.boolValue }
        return nil
    }

    static func slugify(_ value: String) -> String {
        let lowered = value.lowercased().map { character in
            character.isLetter || character.isNumber ? String(character) : "-"
        }.joined()
        return lowered.split(separator: "-").joined(separator: "-").prefix(48).description
    }

    static func displayName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
