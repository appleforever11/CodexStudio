import Foundation

struct AbstractWallpaper: Codable, Identifiable, Sendable {
    let title: String
    let url: URL
    let thumbnail: URL
    let images: String?
    var id: String { "moewalls-" + url.deletingPathExtension().lastPathComponent }
    var name: String { title.replacingOccurrences(of: " Live Wallpaper", with: "") }
}

struct AbstractCatalog: Codable {
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
