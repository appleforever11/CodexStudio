import XCTest
@testable import CodexStudio

final class ThemeModelTests: XCTestCase {
    func testThemeLayoutMetadataIsStable() {
        XCTAssertEqual(ThemeLayout.allCases.map(\.rawValue), ["grid", "list"])
        XCTAssertEqual(ThemeLayout.grid.systemImage, "square.grid.2x2")
        XCTAssertEqual(ThemeLayout.list.systemImage, "list.bullet")
        XCTAssertEqual(ThemeLayout(rawValue: "unknown"), nil)
    }

    func testRecentFilterIsAvailableForNavigation() {
        XCTAssertTrue(ThemeFilter.allCases.contains(.recent))
        XCTAssertEqual(ThemeFilter.recent.label, "Recent")
    }

    func testPlatformReleaseParsesVersionFromCatalogMetadata() {
        let theme = makeTheme(category: "macOS Era", collection: "macOS Era · Golden Gate 27", platformVersion: "27.0")

        XCTAssertEqual(theme.platformRelease?.platform, .macOS)
        XCTAssertEqual(theme.platformRelease?.versionLabel, "Golden Gate 27")
        XCTAssertEqual(theme.platformRelease?.versionComponents, [27, 0])
        XCTAssertEqual(theme.platformRelease?.displayName, "macOS · Golden Gate 27")
    }

    func testPlatformReleaseRejectsNonPlatformThemes() {
        let theme = makeTheme(category: "Landscape", collection: "Signature Collection")

        XCTAssertNil(theme.platformRelease)
    }

    func testCatalogPathGuardsRejectTraversalAndUnsafeIdentifiers() {
        XCTAssertTrue(ThemeLibraryService.isSafeThemeID("golden-gate-27"))
        XCTAssertTrue(ThemeLibraryService.isSafeFileName("background.jpg"))
        XCTAssertFalse(ThemeLibraryService.isSafeThemeID("../golden-gate"))
        XCTAssertFalse(ThemeLibraryService.isSafeThemeID(""))
        XCTAssertFalse(ThemeLibraryService.isSafeFileName("../background.jpg"))
        XCTAssertFalse(ThemeLibraryService.isSafeFileName("nested/background.jpg"))
    }

    private func makeTheme(
        category: String,
        collection: String,
        platformVersion: String? = nil
    ) -> Theme {
        Theme(
            id: "test-theme",
            name: "Test Theme",
            author: "Test Author",
            description: "Test description",
            category: category,
            collection: collection,
            appearance: "dark",
            palette: .fallback,
            imagePath: nil,
            previewPath: nil,
            origin: .local,
            isInstalled: true,
            isCurated: false,
            isFavorite: false,
            focusX: 0.5,
            focusY: 0.5,
            safeArea: "left",
            taskMode: "auto",
            platformVersion: platformVersion
        )
    }
}
