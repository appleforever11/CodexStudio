import XCTest
@testable import CodexStudio

final class ThemeCatalogQueryTests: XCTestCase {
    func testNumericReleaseOrderDoesNotSortTenBeforeNine() {
        let themes = [theme("ten", version: "10.0"), theme("nine", version: "9.3"), theme("eleven", version: "11")]
        let result = ThemeCatalogQuery(order: .platformRelease).results(in: themes)
        XCTAssertEqual(result.map(\.id), ["nine", "ten", "eleven"])
    }

    func testReleaseFilterKeepsPlatformsSeparate() {
        let phone = theme("phone", version: "18")
        let tablet = theme("tablet", category: "iPadOS", version: "18")
        let query = ThemeCatalogQuery(releaseID: phone.platformRelease?.id)
        XCTAssertEqual(query.results(in: [phone, tablet]).map(\.id), ["phone"])
    }

    func testSearchCombinesWithFavoritesAndRelease() {
        let saved = theme("Ocean", version: "18", favorite: true)
        let other = theme("Ocean older", version: "17", favorite: true)
        let unsaved = theme("Ocean new", version: "18")
        let query = ThemeCatalogQuery(filter: .favorites, releaseID: saved.platformRelease?.id, search: " ocean ")
        XCTAssertEqual(query.results(in: [saved, other, unsaved]).map(\.id), ["Ocean"])
    }

    func testRecentUsesActualRecencyInsteadOfSavedSortOrder() {
        let query = ThemeCatalogQuery(filter: .recent, order: .name, recentIDs: ["Z", "A"])
        XCTAssertEqual(query.results(in: [theme("A"), theme("M"), theme("Z")]).map(\.id), ["Z", "A"])
    }

    func testDuplicateAndMissingRecentIDsAreSafe() {
        let query = ThemeCatalogQuery(filter: .recent, recentIDs: ["missing", "Z", "Z", "A"])
        XCTAssertEqual(query.results(in: [theme("A"), theme("Z")]).map(\.id), ["Z", "A"])
    }

    func testReleaseOptionsAreUniqueAndScoped() {
        let query = ThemeCatalogQuery(category: "iOS")
        let releases = query.releases(in: [theme("a", version: "18"), theme("b", version: "18"),
            theme("c", category: "iPadOS", version: "18"), theme("d", version: "9")])
        XCTAssertEqual(releases.map(\.versionComponents), [[9], [18]])
        XCTAssertTrue(releases.allSatisfy { $0.platform == .iOS })
    }

    func testIdenticalNamesHaveStableTieBreaker() {
        var a = theme("a")
        var b = theme("b")
        a.name = "Same"
        b.name = "Same"
        XCTAssertEqual(ThemeCatalogQuery(order: .name).results(in: [b, a]).map(\.id), ["a", "b"])
    }

    func testReleaseOptionsDoNotDuplicateEquivalentCatalogLabels() {
        let first = theme("first", version: "18")
        var second = theme("second", version: "18")
        second.platformVersion = "18.0"
        let releases = ThemeCatalogQuery().releases(in: [first, second])
        XCTAssertEqual(releases.count, 1)
        XCTAssertEqual(releases.first?.id, first.platformRelease?.id)
    }

    @MainActor func testStoreCatalogUpdatesWhenSearchOrFavoriteChanges() {
        let store = StudioStore()
        store.themes = [theme("Ocean", favorite: true), theme("Forest")]
        store.searchText = "Forest"
        XCTAssertEqual(store.filteredThemes.map(\.id), ["Forest"])
        store.themeFilter = .favorites
        XCTAssertTrue(store.filteredThemes.isEmpty)
        store.searchText = ""
        XCTAssertEqual(store.filteredThemes.map(\.id), ["Ocean"])
    }

    @MainActor func testChangingCategoryClearsStaleReleaseFilter() {
        let store = StudioStore()
        let phone = theme("phone", version: "18")
        store.themes = [phone, theme("tablet", category: "iPadOS", version: "18")]
        store.selectedReleaseID = phone.platformRelease?.id
        store.selectedThemeCategory = "iPadOS"
        XCTAssertNil(store.selectedReleaseID)
        XCTAssertEqual(store.filteredThemes.map(\.id), ["tablet"])
    }

    @MainActor func testBackgroundRefreshDoesNotRunDuringApply() {
        let store = StudioStore()
        store.isLoading = false
        store.isApplying = true
        store.refreshRuntime()
        XCTAssertFalse(store.isRefreshingRuntime)
    }

    @MainActor func testApplyingIsBlockedWhileCatalogLoadsOrCodexOpens() {
        let store = StudioStore()
        store.themes = [theme("preview")]
        store.applySelectedTheme()
        XCTAssertFalse(store.isApplying)
        store.isLoading = false
        store.isOpeningCodex = true
        store.applySelectedTheme()
        XCTAssertFalse(store.isApplying)
        store.isOpeningCodex = false
        XCTAssertTrue(store.canApply)
    }

    private func theme(_ id: String, category: String = "iOS", version: String = "18", favorite: Bool = false) -> Theme {
        Theme(id: id, name: id, author: "Apple", description: "Wallpaper", category: category,
            collection: "\(category) · \(version)", appearance: "dark", palette: .fallback,
            imagePath: nil, previewPath: nil, origin: .local, isInstalled: true, isCurated: false,
            isFavorite: favorite, focusX: 0.5, focusY: 0.5, safeArea: "left", taskMode: "auto", platformVersion: version)
    }
}
