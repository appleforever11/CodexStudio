import Foundation

actor MoeCatalogService {
    static let shared = MoeCatalogService()
    static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60
    private var refreshing = false
    private let cache: URL
    private let defaults: UserDefaults
    private let bundled: AbstractCatalog?
    init(cache: URL = ThemeLibraryService.managedThemesDirectory.deletingLastPathComponent().appendingPathComponent("moewalls-catalog.json"),
         bundled: AbstractCatalog? = nil, defaults: UserDefaults = .standard) {
        self.cache = cache
        self.bundled = bundled
        self.defaults = defaults
    }
    func load() throws -> AbstractCatalog {
        if let data = try? Data(contentsOf: cache), let catalog = try? JSONDecoder().decode(AbstractCatalog.self, from: data), !catalog.items.isEmpty { return catalog }
        return try bundled ?? AbstractCatalog.load()
    }
    static func isDue(checked: Date?, attempted: Date?, now: Date = Date()) -> Bool {
        (checked.map { now.timeIntervalSince($0) >= refreshInterval } ?? true)
            && (attempted.map { now.timeIntervalSince($0) >= 24 * 60 * 60 } ?? true)
    }
    func refresh(force: Bool = false) async throws -> AbstractCatalog {
        let existing = try load()
        let stamp = existing.retrievedAt.count == 10 ? existing.retrievedAt + "T00:00:00Z" : existing.retrievedAt
        let checked = ISO8601DateFormatter().date(from: stamp)
        let attempted = defaults.object(forKey: "moeCatalogLastAttempt") as? Date
        guard !refreshing, force || Self.isDue(checked: checked, attempted: attempted) else { return existing }
        // Manual requests are also throttled to protect the source from repeated clicks.
        if force, let attempted, Date().timeIntervalSince(attempted) < 60 {
            throw ThemeImportError.invalidSource("Please wait a minute before checking the catalog again.")
        }
        refreshing = true
        defaults.set(Date(), forKey: "moeCatalogLastAttempt")
        defer { refreshing = false }
        let base = URL(string: "https://moewalls.com/category/abstract/")!
        let first = String(decoding: try await AbstractWallpaperService.download(base, limit: 2 * 1024 * 1024), as: UTF8.self)
        let pages = MoeSourceParser.pageCount(first)
        guard pages <= 100 else { throw ThemeImportError.invalidSource("The source pagination changed. Your saved catalog is unchanged.") }
        var items = try MoeSourceParser.catalogPage(first)
        if pages > 1 {
            for page in 2...pages {
                try await Task.sleep(for: .milliseconds(350))
                let url = base.appendingPathComponent("page/\(page)/")
                let html = String(decoding: try await AbstractWallpaperService.download(url, limit: 2 * 1024 * 1024), as: UTF8.self)
                items += try MoeSourceParser.catalogPage(html)
            }
        }
        var seen = Set<String>()
        items = items.filter { seen.insert($0.id).inserted }
        if let count = MoeSourceParser.matches(#"Here are listed ([0-9]+) Abstract"#, in: first).first.flatMap({ Int($0[1]) }), items.count != count {
            throw ThemeImportError.invalidSource("The source changed while refreshing. Your complete saved catalog is unchanged.")
        }
        let updated = AbstractCatalog(retrievedAt: ISO8601DateFormatter().string(from: Date()), count: items.count, items: items)
        try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: cache, options: .atomic)
        return updated
    }
}
