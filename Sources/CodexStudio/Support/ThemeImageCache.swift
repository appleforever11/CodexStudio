import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Loads artwork off the main actor and keeps a bounded data cache. The theme
/// gallery can contain hundreds of large images, so a card must never decode
/// its file synchronously during layout.
actor ThemeImageCache {
    static let shared = ThemeImageCache()

    private let maximumBytes = 64 * 1024 * 1024
    private let defaultPixelSize = 1600

    private struct CacheKey: Hashable {
        let path: String
        let pixelSize: Int
    }

    private struct Entry {
        let data: Data
        var lastAccess: UInt64
    }

    private var entries: [CacheKey: Entry] = [:]
    private var cachedBytes = 0
    private var accessCounter: UInt64 = 0

    func data(atPath path: String, maxPixelSize: Int? = nil) -> Data? {
        let pixelSize = min(3200, max(96, maxPixelSize ?? defaultPixelSize))
        let key = CacheKey(path: path, pixelSize: pixelSize)
        accessCounter &+= 1
        if var cached = entries[key] {
            cached.lastAccess = accessCounter
            entries[key] = cached
            return cached.data
        }

        guard let data = Self.downsampledData(atPath: path, maxPixelSize: pixelSize) else {
            return nil
        }

        entries[key] = Entry(data: data, lastAccess: accessCounter)
        cachedBytes += data.count
        trimIfNeeded()
        return data
    }

    private func trimIfNeeded() {
        while cachedBytes > maximumBytes, let key = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key {
            if let entry = entries.removeValue(forKey: key) {
                cachedBytes -= entry.data.count
            }
        }
    }

    private static func downsampledData(atPath path: String, maxPixelSize: Int) -> Data? {
        let url = URL(fileURLWithPath: path) as CFURL
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url, options) else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary),
              let destinationData = NSMutableData(length: 0),
              let destination = CGImageDestinationCreateWithData(
                  destinationData,
                  UTType.png.identifier as CFString,
                  1,
                  nil
              )
        else {
            // Never fall back to an unbounded full-resolution decode in a
            // scrolling gallery. An unreadable asset gets the safe placeholder.
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }
}
