import Foundation

/// A single, deterministic query for every catalog entry point. No view sorts
/// the entire library while it is laying out cards or receiving runtime ticks.
struct ThemeCatalogQuery {
    var filter: ThemeFilter = .all
    var category = "All"
    var releaseID: String?
    var search = ""
    var order: ThemeSortOrder = .featured
    var recentIDs: [String] = []

    func matchesScope(_ theme: Theme) -> Bool {
        switch filter {
        case .all: true
        case .curated: theme.isCurated
        case .local: theme.isInstalled
        case .favorites: theme.isFavorite
        case .recent: recentIDs.contains(theme.id)
        }
    }

    func results(in themes: [Theme]) -> [Theme] {
        let phrase = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = themes.filter { theme in
            guard matchesScope(theme), category == "All" || theme.category == category,
                  releaseID == nil || theme.platformRelease?.id == releaseID else { return false }
            return phrase.isEmpty || [theme.name, theme.author, theme.category, theme.collection,
                theme.description, theme.platformVersion ?? "", theme.platformRelease?.displayName ?? ""]
                .joined(separator: " ").localizedStandardContains(phrase)
        }
        let recency = Dictionary(recentIDs.enumerated().map { ($1, $0) }, uniquingKeysWith: min)
        return matches.sorted { left, right in
            if filter == .recent {
                return recency[left.id, default: .max] < recency[right.id, default: .max]
            }
            switch order {
            case .featured:
                if left.isCurated != right.isCurated { return left.isCurated }
                if left.isFavorite != right.isFavorite { return left.isFavorite }
            case .category:
                if left.category != right.category { return left.category < right.category }
            case .platformRelease:
                switch (left.platformRelease, right.platformRelease) {
                case let (lhs?, rhs?) where lhs != rhs:
                    return Self.releaseBefore(lhs, rhs)
                case (.some, .none): return true
                case (.none, .some): return false
                default: break
                }
            case .name: break
            }
            let comparison = left.name.localizedStandardCompare(right.name)
            return comparison == .orderedSame ? left.id < right.id : comparison == .orderedAscending
        }
    }

    func releases(in themes: [Theme]) -> [ThemePlatformRelease] {
        let candidates = themes.filter { matchesScope($0) && (category == "All" || $0.category == category) }
            .compactMap(\.platformRelease)
        return Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            .values.sorted(by: Self.releaseBefore)
    }

    static func releaseBefore(_ lhs: ThemePlatformRelease, _ rhs: ThemePlatformRelease) -> Bool {
        if lhs.platform != rhs.platform { return lhs.platform.sortIndex < rhs.platform.sortIndex }
        if lhs.versionComponents != rhs.versionComponents {
            return lhs.versionComponents.lexicographicallyPrecedes(rhs.versionComponents)
        }
        return lhs.versionLabel.localizedStandardCompare(rhs.versionLabel) == .orderedAscending
    }
}

enum StudioPlatform: String, CaseIterable, Identifiable {
    case macOS, iOS, iPadOS
    var id: String { rawValue }
    var category: String { self == .macOS ? "macOS Era" : rawValue }
    var symbol: String {
        switch self {
        case .macOS: "desktopcomputer"
        case .iOS: "iphone"
        case .iPadOS: "ipad.landscape"
        }
    }
}
