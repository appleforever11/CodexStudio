import XCTest
@testable import CodexStudio

final class AbstractWallpaperTests: XCTestCase {
    func testRelativePreviewAndQuery() throws {
        let page = URL(string: "https://moewalls.com/abstract/example/")!
        let url = try AbstractWallpaperService.previewURL(html: #"<video src='/wp-content/uploads/preview/example.webm?x=1&amp;y=2'></video>"#, page: page)
        XCTAssertEqual(url.absoluteString, "https://moewalls.com/wp-content/uploads/preview/example.webm?x=1&y=2")
    }
    func testRejectsExternalAndNonMediaSources() {
        let page = URL(string: "https://moewalls.com/abstract/example/")!
        for html in [#"<video src='https://other.example/clip.mp4'>"#, #"<video src='file:///tmp/clip.mp4'>"#, "<html>No video</html>"] {
            XCTAssertThrowsError(try AbstractWallpaperService.previewURL(html: html, page: page))
        }
    }

    func testOriginalQualityUsesPostResolutionAndOfficialDownloadToken() throws {
        let html = """
        <nav><a href='/resolution/7680x4320/'>8K</a></nav>
        original resolution is <strong><a href='/resolution/3840x2160/'>3840x2160</a></strong>
        <a data-url='abc%2B123%3D' id='moe-download'>Download</a>
        <video src='/wp-content/uploads/preview/sample.webm'></video>
        """
        let options = try MoeSourceParser.options(html: html, page: URL(string: "https://moewalls.com/abstract/test/")!)
        XCTAssertEqual(options.map(\.id), ["original", "preview"])
        XCTAssertEqual(options[0].label, "Original · 3840 × 2160")
        XCTAssertEqual(options[0].url.absoluteString, "https://go.moewalls.com/download.php?video=abc%2B123%3D")
        XCTAssertFalse(options[1].original)
    }
    func testCatalogParsingRejectsAdsAndDecodesTitles() throws {
        let html = """
        <div class='entry-featured-media'><a title='Purple &amp; Blue &#8211; Live Wallpaper' href='https://moewalls.com/abstract/purple/'><img src='https://moewalls.com/wp-content/uploads/purple.jpg' srcset='https://moewalls.com/wp-content/uploads/purple.jpg 1920w'></a></div>
        <div class='entry-featured-media'><a title='Ad' href='https://ad.example/'><img src='https://ad.example/a.jpg'></a></div>
        <a href='/category/abstract/page/17/'>Last</a>
        """
        let items = try MoeSourceParser.catalogPage(html)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Purple & Blue – Live Wallpaper")
        XCTAssertEqual(MoeSourceParser.pageCount(html), 17)
        XCTAssertThrowsError(try MoeSourceParser.catalogPage("<html>Unavailable</html>"))
    }
    func testRefreshCadenceAndFailureBackoff() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertFalse(MoeCatalogService.isDue(checked: now.addingTimeInterval(-6 * 86400), attempted: nil, now: now))
        XCTAssertTrue(MoeCatalogService.isDue(checked: now.addingTimeInterval(-8 * 86400), attempted: nil, now: now))
        XCTAssertFalse(MoeCatalogService.isDue(checked: nil, attempted: now.addingTimeInterval(-3600), now: now))
        XCTAssertTrue(MoeCatalogService.isDue(checked: nil, attempted: now.addingTimeInterval(-90000), now: now))
    }
    func testDownloadHostBoundary() {
        XCTAssertTrue(MoeMediaDownload.allowed(URL(string: "https://go.moewalls.com/download.php?video=a")))
        XCTAssertFalse(MoeMediaDownload.allowed(URL(string: "http://moewalls.com/video.mp4")))
        XCTAssertFalse(MoeMediaDownload.allowed(URL(string: "https://moewalls.com.evil.example/video.mp4")))
    }

    func testLiveOriginalImportWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["MOE_LIVE_IMPORT_TEST"] == "1" else { throw XCTSkip("Opt-in network and media conversion check") }
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try JSONDecoder().decode(AbstractCatalog.self, from: Data(contentsOf: repo.appendingPathComponent("Resources/MoeWallsAbstract.json")))
        let item = try XCTUnwrap(catalog.items.first { $0.url.path.contains("abstract-vibrant-purple-and-blue-light-beam") })
        let options = try await AbstractWallpaperService.options(for: item)
        let original = try XCTUnwrap(options.first { $0.original })
        XCTAssertEqual(original.label, "Original · 3840 × 2160")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("moe-live-quality-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let id = try await AbstractWallpaperService.importAnimation(item, option: original, libraryRoot: root, converterURL: repo.appendingPathComponent("Resources/convert-wallpaper.sh"))
        let theme = root.appendingPathComponent(id)
        let data = try Data(contentsOf: theme.appendingPathComponent("background.webp"))
        XCTAssertLessThanOrEqual(data.count, 10 * 1024 * 1024)
        XCTAssertEqual(String(decoding: data[12..<16], as: UTF8.self), "VP8X")
        func dimension(_ start: Int) -> Int { 1 + Int(data[start]) + (Int(data[start + 1]) << 8) + (Int(data[start + 2]) << 16) }
        XCTAssertEqual(dimension(24), 3840)
        XCTAssertEqual(dimension(27), 2160)
        XCTAssertNotEqual(data[20] & 2, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: theme.appendingPathComponent("source.media").path))
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: theme.appendingPathComponent("catalog.json"))) as? [String: Any])
        XCTAssertEqual(saved["localOnly"] as? Bool, true)
        let firstPage = try await AbstractWallpaperService.download(URL(string: "https://moewalls.com/category/abstract/")!, limit: 2 * 1024 * 1024)
        let html = String(decoding: firstPage, as: UTF8.self)
        XCTAssertEqual(MoeSourceParser.pageCount(html), 17)
        XCTAssertGreaterThan(try MoeSourceParser.catalogPage(html).count, 0)
        print("LIVE MOEWALLS PASS: original 3840x2160, animated, \(data.count) bytes, temporary video removed, localOnly, live catalog parsed")
    }

    func testLiveCatalogRefreshWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["MOE_LIVE_CATALOG_TEST"] == "1" else { throw XCTSkip("Opt-in full catalog refresh check") }
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let seed = try JSONDecoder().decode(AbstractCatalog.self, from: Data(contentsOf: repo.appendingPathComponent("Resources/MoeWallsAbstract.json")))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("moe-catalog-test-\(UUID().uuidString)")
        let suite = "moe-catalog-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            try? FileManager.default.removeItem(at: root)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        let service = MoeCatalogService(cache: root.appendingPathComponent("catalog.json"), bundled: seed, defaults: defaults)
        let refreshed = try await service.refresh(force: true)
        XCTAssertGreaterThanOrEqual(refreshed.items.count, seed.items.count)
        XCTAssertEqual(Set(refreshed.items.map(\.id)).count, refreshed.items.count)
        let saved = try await service.load()
        XCTAssertEqual(saved.retrievedAt, refreshed.retrievedAt)
        let cached = try await service.refresh()
        XCTAssertEqual(cached.retrievedAt, refreshed.retrievedAt)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["catalog.json"])
        print("LIVE CATALOG PASS: \(saved.items.count) unique wallpapers, all pages refreshed, metadata-only cache, weekly cache reuse")
    }

    func testLargePreviewUsesLargestAdvertisedImage() {
        let thumbnail = URL(string: "https://moewalls.com/wp-content/uploads/thumb.jpg")!
        let item = AbstractWallpaper(title: "Test", url: URL(string: "https://moewalls.com/abstract/test/")!, thumbnail: thumbnail,
                                     images: "https://moewalls.com/wp-content/uploads/small.jpg 364w, https://moewalls.com/wp-content/uploads/large.jpg 1920w, https://other.example/large.jpg 9000w")
        XCTAssertEqual(item.previewImageURL.lastPathComponent, "large.jpg")
        let fallback = AbstractWallpaper(title: item.title, url: item.url, thumbnail: thumbnail, images: nil)
        XCTAssertEqual(fallback.previewImageURL, thumbnail)
    }

    func testAbstractLibrarySortAndFilterOptionsRemainStable() {
        XCTAssertEqual(AbstractSortOption.allCases.map(\.rawValue), [
            "recommended", "newest", "name", "largestPreview", "recentlyViewed"
        ])
        XCTAssertEqual(AbstractFilterOption.allCases.map(\.rawValue), [
            "all", "imported", "favorites", "largePreview"
        ])
        XCTAssertEqual(AbstractSortOption.largestPreview.title, "Largest preview")
        XCTAssertEqual(AbstractFilterOption.largePreview.title, "Large previews")
    }

    @MainActor func testAnimationPreviewDocumentStaysIsolated() {
        let html = MoeAnimationPreview.document(url: URL(string: "https://moewalls.com/wp-content/uploads/preview/test.webm?a=1&b=2")!)
        XCTAssertTrue(html.contains("<video"))
        XCTAssertTrue(html.contains("controls autoplay muted loop"))
        XCTAssertTrue(html.contains("a=1&amp;b=2"))
        XCTAssertTrue(html.contains("default-src 'none'"))
        XCTAssertTrue(html.contains("video.addEventListener('error'"))
        XCTAssertEqual(MoeAnimationPreview.document(url: URL(string: "https://example.com/test.webm")!), "")
    }

    func testMissingSourceIsNotReportedAsSizeLimit() throws {
        let response = HTTPURLResponse(url: URL(string: "https://moewalls.com/error-file?err=1005")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"])!
        XCTAssertThrowsError(try MoeMediaDownload.validate(response: response, size: 4096)) { error in
            XCTAssertEqual(error as? MoeMediaError, .unavailable)
            XCTAssertFalse(error.localizedDescription.contains("512"))
        }
        let media = HTTPURLResponse(url: URL(string: "https://moewalls.com/wp-content/uploads/test.webm")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "video/webm"])!
        XCTAssertNoThrow(try MoeMediaDownload.validate(response: media, size: 951235))
        XCTAssertThrowsError(try MoeMediaDownload.validate(response: media, size: MoeMediaDownload.maximumBytes + 1)) { error in
            XCTAssertEqual(error as? MoeMediaError, .tooLarge)
        }
    }
}
