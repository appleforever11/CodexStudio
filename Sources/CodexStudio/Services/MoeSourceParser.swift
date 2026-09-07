import Foundation

struct MoeDownloadOption: Identifiable, Sendable {
    let id: String
    let label: String
    let url: URL
    let original: Bool
}

enum MoeSourceParser {
    static func matches(_ pattern: String, in html: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).map { match in
            (0..<match.numberOfRanges).map { Range(match.range(at: $0), in: html).map { String(html[$0]) } ?? "" }
        }
    }
    static func decode(_ value: String) -> String {
        var result = value
        for (a, b) in [("&amp;", "&"), ("&quot;", "\""), ("&#039;", "'"), ("&apos;", "'"), ("&nbsp;", " ")] { result = result.replacingOccurrences(of: a, with: b) }
        for match in matches(#"&#(x[0-9a-f]+|[0-9]+);"#, in: result) {
            let hex = match[1].lowercased().hasPrefix("x")
            if let code = UInt32(hex ? String(match[1].dropFirst()) : match[1], radix: hex ? 16 : 10), let scalar = UnicodeScalar(code) {
                result = result.replacingOccurrences(of: match[0], with: String(scalar))
            }
        }
        return result
    }
    static func attribute(_ name: String, in tag: String) -> String? {
        matches("(?:^|\\s)" + NSRegularExpression.escapedPattern(for: name) + #"\s*=\s*["']([^"']*)["']"#, in: tag).first.map { decode($0[1]) }
    }
    static func options(html: String, page: URL) throws -> [MoeDownloadOption] {
        var result: [MoeDownloadOption] = []
        // Resolution comes from this post's description, never the site's navigation menu.
        let resolution = matches(#"original resolution is\s*(?:<[^>]+>\s*)*([0-9]+)[x×]([0-9]+)"#, in: html).first
        for tag in matches(#"<a\b[^>]*>"#, in: html).map({ $0[0] }) where attribute("id", in: tag) == "moe-download" {
            if let token = attribute("data-url", in: tag), !token.isEmpty,
               token.range(of: #"^[A-Za-z0-9%+/=]+$"#, options: .regularExpression) != nil,
               let url = URL(string: "https://go.moewalls.com/download.php?video=" + token) {
                let label = resolution.map { "Original · \($0[1]) × \($0[2])" } ?? "Original · source resolution"
                result.append(MoeDownloadOption(id: "original", label: label, url: url, original: true))
            }
        }
        if let preview = try? AbstractWallpaperService.previewURL(html: html, page: page) {
            result.append(MoeDownloadOption(id: "preview", label: "Preview · smaller download", url: preview, original: false))
        }
        guard !result.isEmpty else { throw ThemeImportError.invalidSource("No download options found. Open the source page to check availability.") }
        return result
    }
    static func catalogPage(_ html: String) throws -> [AbstractWallpaper] {
        var result: [AbstractWallpaper] = []
        for block in matches(#"<div\b[^>]*class=["'][^"']*entry-featured-media[^"']*["'][^>]*>(.*?)</a>"#, in: html) {
            guard let anchor = matches(#"<a\b[^>]*>"#, in: block[1]).first?[0],
                  let image = matches(#"<img\b[^>]*>"#, in: block[1]).first?[0],
                  let title = attribute("title", in: anchor), let href = attribute("href", in: anchor),
                  let url = URL(string: href), url.scheme == "https", url.host == "moewalls.com", url.path.hasPrefix("/abstract/"),
                  let src = attribute("src", in: image), let thumbnail = URL(string: src),
                  thumbnail.scheme == "https", thumbnail.host == "moewalls.com" else { continue }
            result.append(AbstractWallpaper(title: title, url: url, thumbnail: thumbnail, images: attribute("srcset", in: image)))
        }
        guard !result.isEmpty else { throw ThemeImportError.invalidSource("MoeWalls returned an unfamiliar catalog page. Your saved catalog is unchanged.") }
        return result
    }
    static func pageCount(_ html: String) -> Int {
        matches(#"/category/abstract/page/([0-9]+)/"#, in: html).compactMap { Int($0[1]) }.max() ?? 1
    }
}
