import Foundation

/// Loads artwork off the main actor and keeps a bounded data cache. The theme
/// gallery can contain hundreds of large images, so a card must never decode
/// its file synchronously during layout.
actor ThemeImageCache {
    static let shared = ThemeImageCache()

    private let maximumBytes = 64 * 1024 * 1024
    private var dataByPath: [String: Data] = [:]
    private var cachedBytes = 0

    func data(atPath path: String) -> Data? {
        if let cached = dataByPath[path] {
            return cached
        }

        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return nil
        }

        dataByPath[path] = data
        cachedBytes += data.count
        trimIfNeeded()
        return data
    }

    private func trimIfNeeded() {
        while cachedBytes > maximumBytes, let path = dataByPath.keys.first {
            if let data = dataByPath.removeValue(forKey: path) {
                cachedBytes -= data.count
            }
        }
    }
}
