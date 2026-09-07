import Foundation
import CryptoKit

/// Personal-use imports stay in the local library; the bundled catalog contains links only.
struct AbstractWallpaperService {
    static func download(_ url: URL, limit: Int) async throws -> Data {
        guard url.scheme == "https", url.host == "moewalls.com" else {
            throw ThemeImportError.invalidSource("The wallpaper source must be MoeWalls over HTTPS.")
        }
        var request = URLRequest(url: url, timeoutInterval: 45)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.url?.host == "moewalls.com", response.expectedContentLength <= limit else {
            throw ThemeImportError.invalidSource("MoeWalls could not provide this wallpaper. Try its source page.")
        }
        var data = Data()
        for try await byte in bytes {
            if data.count >= limit { throw ThemeImportError.invalidSource("This wallpaper exceeds the import size limit.") }
            data.append(byte)
        }
        return data
    }

    static func previewURL(html: String, page: URL) throws -> URL {
        let regex = try NSRegularExpression(pattern: #"(?:src)\s*=\s*["']([^"']+\.(?:webm|mp4)(?:\?[^"']*)?)["']"#, options: .caseInsensitive)
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let value = Range(match.range(at: 1), in: html),
              let url = URL(string: String(html[value]).replacingOccurrences(of: "&amp;", with: "&"), relativeTo: page)?.absoluteURL,
              url.scheme == "https", url.host == "moewalls.com", url.path.hasPrefix("/wp-content/uploads/") else {
            throw ThemeImportError.invalidSource("No supported animation preview was found. Open the source page to check availability.")
        }
        return url
    }

    static func options(for item: AbstractWallpaper) async throws -> [MoeDownloadOption] {
        let html = try await download(item.url, limit: 2 * 1024 * 1024)
        return try MoeSourceParser.options(html: String(decoding: html, as: UTF8.self), page: item.url)
    }

    static func importAnimation(_ item: AbstractWallpaper, option: MoeDownloadOption, libraryRoot: URL? = nil, converterURL: URL? = nil) async throws -> String {
        let root = libraryRoot ?? ThemeLibraryService.managedThemesDirectory
        let digest = SHA256.hash(data: Data(item.url.absoluteString.utf8)).prefix(6).map { String(format: "%02x", $0) }.joined()
        let themeID = String(item.id.prefix(48)) + "-" + digest + "-" + option.id
        let destination = root.appendingPathComponent(themeID)
        if FileManager.default.fileExists(atPath: destination.path) { return themeID }
        guard let converter = converterURL ?? Bundle.main.url(forResource: "convert-wallpaper", withExtension: "sh") else {
            throw ThemeImportError.invalidSource("The animation converter is missing from this build.")
        }
        let mediaURL = option.url
        let poster = try await download(item.thumbnail, limit: 4 * 1024 * 1024)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let stage = root.appendingPathComponent(".abstract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: stage) }
        let input = stage.appendingPathComponent("source.media")
        try await MoeMediaDownload.save(mediaURL, to: input)
        try poster.write(to: stage.appendingPathComponent("preview.jpg"))
        let result = await Task.detached {
            RuntimeProcessRunner.run(script: converter, arguments: [input.path, stage.appendingPathComponent("background.webp").path, option.original ? "original" : "preview"], timeout: 240)
        }.value
        guard result.completed, result.exitCode == 0 else {
            throw ThemeImportError.invalidSource("Animation conversion failed. \(result.detail)")
        }
        let size = try stage.appendingPathComponent("background.webp").resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 10 * 1024 * 1024 else { throw ThemeImportError.invalidSource("The converted animation exceeds 10 MB.") }
        try FileManager.default.removeItem(at: input)
        let theme: [String: Any] = ["schemaVersion": 1, "id": themeID, "name": item.name + (option.original ? " · Original" : " · Preview"),
            "image": "background.webp", "preview": "preview.jpg", "category": "Abstract",
            "collection": "MoeWalls Abstract", "author": "See original creator on MoeWalls", "appearance": "dark",
            "description": "Source: \(option.label). Short animated WebP loop. Personal-use local import.", "promoUrl": item.url.absoluteString,
            "art": ["taskMode": "full", "safeArea": "auto"]]
        let catalog: [String: Any] = ["schemaVersion": 1, "localOnly": true, "category": "Abstract",
            "collection": "MoeWalls Abstract", "sourceURL": item.url.absoluteString, "imageURL": mediaURL.absoluteString,
            "rightsStatus": "Personal, non-commercial use; rights remain with original owners",
            "summary": "\(option.label). Converted on demand; original dimensions retained for Original quality. Loop duration and frame rate are reduced."]
        try JSONSerialization.data(withJSONObject: theme, options: .prettyPrinted).write(to: stage.appendingPathComponent("theme.json"))
        try JSONSerialization.data(withJSONObject: catalog, options: .prettyPrinted).write(to: stage.appendingPathComponent("catalog.json"))
        try "Source: \(item.url)\nMedia: \(mediaURL)\nRights remain with original owners. Personal, non-commercial use. Local only.\n".write(to: stage.appendingPathComponent("LICENSE.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.moveItem(at: stage, to: destination)
        return themeID
    }
}
