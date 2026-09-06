import AppKit
import SwiftUI
import OSLog

extension StudioStore {
    func selectSection(_ nextSection: StudioSection) {
        logger.debug("Selected section: \(nextSection.rawValue, privacy: .public)")
        section = nextSection
        if nextSection == .library {
            themeFilter = .local
            resetCatalogFilters()
        }
    }

    func selectThemes(filter: ThemeFilter = .all) {
        section = .themes
        themeFilter = filter
        resetCatalogFilters()
    }

    func resetCatalogFilters() {
        searchText = ""
        selectedThemeCategory = "All"
        selectedReleaseID = nil
    }

    func selectPlatform(_ platform: StudioPlatform) {
        selectThemes()
        selectedThemeCategory = platform.category
        setThemeSortOrder(.platformRelease)
    }

    func selectFavorites() {
        selectThemes(filter: .favorites)
    }

    func selectRecent() {
        selectThemes(filter: .recent)
    }

    func setThemeSortOrder(_ order: ThemeSortOrder) {
        themeSortOrder = order
        defaults.set(order.rawValue, forKey: Keys.themeSortOrder)
    }

    func setThemeLayout(_ layout: ThemeLayout) {
        themeLayout = layout
        defaults.set(layout.rawValue, forKey: Keys.themeLayout)
    }

    func selectTheme(_ theme: Theme, openEditor: Bool = false) {
        selectedThemeID = theme.id
        defaults.set(theme.id, forKey: Keys.selectedThemeID)
        recordRecentTheme(theme.id)
        logger.debug("Selected theme: \(theme.id, privacy: .public)")
        resetEditorControls(for: theme)
        if openEditor { section = .editor }
    }

    func recordRecentTheme(_ id: String) {
        recentThemeIDs.removeAll { $0 == id }
        recentThemeIDs.insert(id, at: 0)
        recentThemeIDs = Array(recentThemeIDs.prefix(8))
        defaults.set(recentThemeIDs, forKey: Keys.recentThemeIDs)
    }

    func toggleFavorite(_ theme: Theme) {
        guard let index = themes.firstIndex(where: { $0.id == theme.id }) else { return }
        themes[index].isFavorite.toggle()
        let ids = themes.filter(\.isFavorite).map(\.id)
        defaults.set(ids, forKey: Keys.favoriteIDs)
        logger.info("Favorite changed: \(theme.id, privacy: .public) -> \(self.themes[index].isFavorite, privacy: .public)")
        showNotice(
            themes[index].isFavorite
                ? themes[index].name + " added to Favorites."
                : themes[index].name + " removed from Favorites."
        )
    }

}
