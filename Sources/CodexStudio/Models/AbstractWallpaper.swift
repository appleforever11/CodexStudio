import Foundation

struct AbstractWallpaper: Codable, Identifiable, Sendable {
    let title: String
    let url: URL
    let thumbnail: URL
    let images: String?
    var id: String { "moewalls-" + url.deletingPathExtension().lastPathComponent }
    var previewImageURL: URL {
        let candidates = (images ?? "").split(separator: ",").compactMap { entry -> (URL, Int)? in
            let parts = entry.split(whereSeparator: { $0.isWhitespace })
            guard parts.count == 2, parts[1].hasSuffix("w"), let width = Int(parts[1].dropLast()),
                  let url = URL(string: String(parts[0])), url.scheme == "https", url.host == "moewalls.com" else { return nil }
            return (url, width)
        }
        return candidates.max(by: { $0.1 < $1.1 })?.0 ?? thumbnail
    }
    var previewWidth: Int? {
        let widths = (images ?? "").split(separator: ",").compactMap { entry -> Int? in
            let parts = entry.split(whereSeparator: { $0.isWhitespace })
            guard parts.count == 2, parts[1].hasSuffix("w") else { return nil }
            return Int(parts[1].dropLast())
        }
        return widths.max()
    }
    var name: String { title.replacingOccurrences(of: " Live Wallpaper", with: "") }
}

enum AbstractSortOption: String, CaseIterable, Identifiable {
    case recommended
    case newest
    case name
    case largestPreview
    case recentlyViewed

    var id: String { rawValue }
    var title: String {
        switch self {
        case .recommended: "Recommended"
        case .newest: "Newest"
        case .name: "Name"
        case .largestPreview: "Largest preview"
        case .recentlyViewed: "Recently viewed"
        }
    }
}

enum AbstractFilterOption: String, CaseIterable, Identifiable {
    case all
    case imported
    case favorites
    case largePreview

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "All wallpapers"
        case .imported: "Imported"
        case .favorites: "Favorites"
        case .largePreview: "Large previews"
        }
    }
}

struct AbstractCatalog: Codable, Sendable {
    let retrievedAt: String
    let count: Int
    let items: [AbstractWallpaper]
    static func load() throws -> Self {
        guard let url = Bundle.main.url(forResource: "MoeWallsAbstract", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}
