import AppKit
import SwiftUI
import OSLog

extension StudioStore {
    func updateCatalog() {
        let query = ThemeCatalogQuery(filter: themeFilter, category: selectedThemeCategory,
            releaseID: selectedReleaseID, search: searchText, order: themeSortOrder, recentIDs: recentThemeIDs)
        filteredThemes = query.results(in: themes)
        availableReleases = query.releases(in: themes)
    }

    var themeCategories: [String] {
        let visibleSource = themes.filter { theme in
            switch themeFilter {
            case .all: true
            case .curated: theme.isCurated
            case .local: theme.isInstalled
            case .favorites: theme.isFavorite
            case .recent: recentThemeIDs.contains(theme.id)
            }
        }
        let categories = Set(visibleSource.map(\.category).filter { !$0.isEmpty })
        return ["All"] + categories.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var featuredThemes: [Theme] {
        let curated = themes.filter(\.isCurated)
        let candidates = curated.isEmpty ? themes.filter(\.isInstalled) : curated
        return candidates.sorted(by: isFeaturedBefore).prefix(8).map { $0 }
    }

    var quickSwitchThemes: [Theme] {
        let installed = themes.filter(\.isInstalled)
        if installed.count <= 6 { return installed }
        var result = Array(installed.prefix(5))
        if let selectedTheme, !result.contains(where: { $0.id == selectedTheme.id }) {
            result.append(selectedTheme)
        }
        return result
    }

    var favoriteCount: Int {
        themes.reduce(into: 0) { count, theme in
            if theme.isFavorite { count += 1 }
        }
    }

    var recentThemes: [Theme] {
        recentThemeIDs.compactMap { id in themes.first(where: { $0.id == id }) }
    }

}
