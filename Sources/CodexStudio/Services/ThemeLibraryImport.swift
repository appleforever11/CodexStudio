// Local theme-folder import and atomic managed-library publishing.

import Foundation

extension ThemeLibraryService {

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

}
