import SwiftUI

private enum ThemeGalleryMetrics {
    static let sectionSpacing: CGFloat = 28
    static let cardSpacing: CGFloat = 20
    static let horizontalPadding: CGFloat = 28
    static let verticalPadding: CGFloat = 26

    static var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 264, maximum: 370), spacing: cardSpacing, alignment: .top)]
    }
}

struct ThemesPage: View {
    @EnvironmentObject private var store: StudioStore

    private var isFavorites: Bool {
        store.themeFilter == .favorites
    }

    private var appleShelfEyebrow: String? {
        if isFavorites {
            return "FAVORITES · SAVED WORLDS"
        }
        return switch store.selectedThemeCategory {
        case "macOS Era": "MACOS ERA · LOCAL SHELF"
        case "iOS": "IOS · LOCAL SHELF"
        case "iPadOS": "IPADOS · LOCAL SHELF"
        default: nil
        }
    }

    private var appleShelfDetail: String? {
        if isFavorites {
            let noun = store.filteredThemes.count == 1 ? "theme" : "themes"
            return store.filteredThemes.isEmpty
                ? "Star any theme to keep it here for instant switching."
                : "\(store.filteredThemes.count) saved \(noun), kept locally for instant switching."
        }
        guard appleShelfEyebrow != nil else { return nil }
        let noun = store.filteredThemes.count == 1 ? "wallpaper" : "wallpapers"
        return "\(store.filteredThemes.count) official Apple \(store.selectedThemeCategory) \(noun) adapted for Mac and kept local for personal use."
    }

    private var spotlightTheme: Theme? {
        if let selected = store.selectedTheme,
           store.filteredThemes.contains(where: { $0.id == selected.id }) {
            return selected
        }
        return store.filteredThemes.first
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ThemeGalleryMetrics.sectionSpacing) {
                ThemeAtlasHeader(
                    eyebrow: appleShelfEyebrow
                        ?? (store.sourceSummary.curatedCount > 0 ? "CURATED THEME LIBRARY" : "LOCAL THEME LIBRARY"),
                    title: isFavorites ? "Your saved worlds." : "Find a world worth working in.",
                    detail: appleShelfDetail
                        ?? (store.sourceSummary.curatedCount > 0
                            ? "\(store.filteredThemes.count) themes in this view. Every Curated entry includes its creator, source, and rights record."
                            : "\(store.filteredThemes.count) local themes in this view, ready without a network dependency."),
                    symbol: isFavorites ? "star.fill" : "sparkles.rectangle.stack.fill"
                )

                if let selectedTheme = spotlightTheme {
                    ThemeSpotlight(theme: selectedTheme)
                }

                ThemeAtlasControls()
                ThemeCategoryRail()

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isFavorites
                            ? "Favorites"
                            : (store.selectedThemeCategory == "All" ? "All directions" : store.selectedThemeCategory))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(StudioColor.text)
                        Text("\(store.filteredThemes.count) distinct theme\(store.filteredThemes.count == 1 ? "" : "s")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(StudioColor.textFaint)
                    }
                    Spacer()
                    Text("SELECT A CARD TO CHANGE THE STAGE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.25)
                        .foregroundStyle(StudioColor.textFaint)
                }

                if store.isLoading {
                    ThemeAtlasLoadingState(
                        title: "Loading local worlds",
                        detail: "Reading bundled and installed themes…"
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else if store.filteredThemes.isEmpty {
                    ThemeAtlasEmptyState(
                        title: isFavorites ? "No favorites yet" : "No worlds found",
                        detail: isFavorites
                            ? "Click the star on any theme to save it here for quick access."
                            : "Try another category, filter, or search phrase.",
                        symbol: isFavorites ? "star" : "sparkle.magnifyingglass"
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVGrid(
                        columns: ThemeGalleryMetrics.columns,
                        spacing: ThemeGalleryMetrics.cardSpacing
                    ) {
                        ForEach(store.filteredThemes) { theme in
                            ThemeAtlasCard(theme: theme, isSelected: store.selectedTheme?.id == theme.id)
                        }
                    }
                }
            }
            .padding(.horizontal, ThemeGalleryMetrics.horizontalPadding)
            .padding(.vertical, ThemeGalleryMetrics.verticalPadding)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }
}

struct LibraryPage: View {
    @EnvironmentObject private var store: StudioStore

    private var localThemes: [Theme] {
        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.themes
            .filter(\.isInstalled)
            .filter { theme in
                let categoryMatches = store.selectedThemeCategory == "All" || theme.category == store.selectedThemeCategory
                let queryMatches = query.isEmpty || [theme.name, theme.category, theme.collection, theme.description]
                    .joined(separator: " ")
                    .lowercased()
                    .contains(query)
                return categoryMatches && queryMatches
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ThemeGalleryMetrics.sectionSpacing) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 18) {
                        installedHeader
                        Spacer(minLength: 10)
                        importButton
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        installedHeader
                        importButton
                    }
                }

                if let selectedTheme = store.selectedTheme, selectedTheme.isInstalled {
                    ThemeSpotlight(theme: selectedTheme, compact: true)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        AtlasSearchField()
                        LibraryMetric(title: "\(store.sourceSummary.localCount) installed", symbol: "internaldrive.fill", tint: StudioColor.cyan)
                        LibraryMetric(title: "\(store.sourceSummary.wallBuddyCount) local images", symbol: "photo.on.rectangle", tint: StudioColor.orchid)
                        Spacer()
                        Button {
                            store.revealManagedThemes()
                        } label: {
                            Label("Reveal folder", systemImage: "folder")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(StudioColor.textMuted)
                        }
                        .buttonStyle(StudioPressableButtonStyle())
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        AtlasSearchField()
                        HStack {
                            LibraryMetric(title: "\(store.sourceSummary.localCount) installed", symbol: "internaldrive.fill", tint: StudioColor.cyan)
                            LibraryMetric(title: "\(store.sourceSummary.wallBuddyCount) local images", symbol: "photo.on.rectangle", tint: StudioColor.orchid)
                        }
                    }
                }

                ThemeCategoryRail()

                HStack {
                    Text("Installed worlds")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioColor.text)
                    Spacer()
                    Text("\(localThemes.count) visible")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(StudioColor.textFaint)
                }

                if store.isLoading {
                    ThemeAtlasLoadingState(
                        title: "Loading installed worlds",
                        detail: "Checking the local theme library…"
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else if localThemes.isEmpty {
                    ThemeAtlasEmptyState(
                        title: "Nothing matches this view",
                        detail: "Clear the search or choose another category."
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    LazyVGrid(
                        columns: ThemeGalleryMetrics.columns,
                        spacing: ThemeGalleryMetrics.cardSpacing
                    ) {
                        ForEach(localThemes) { theme in
                            ThemeAtlasCard(theme: theme, isSelected: store.selectedTheme?.id == theme.id)
                        }
                    }
                }
            }
            .padding(.horizontal, ThemeGalleryMetrics.horizontalPadding)
            .padding(.vertical, ThemeGalleryMetrics.verticalPadding)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }
}

private extension LibraryPage {
    var installedHeader: some View {
        ThemeAtlasHeader(
            eyebrow: "INSTALLED LIBRARY",
            title: "Every world, ready at hand.",
            detail: "Bundled and imported themes live locally, remain reversible, and switch without a network dependency.",
            symbol: "square.stack.3d.up.fill"
        )
    }

    var importButton: some View {
        Button {
            store.importThemeFolder()
        } label: {
            Label("Import theme", systemImage: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(StudioColor.ink)
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(StudioColor.spectrum, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(StudioPressableButtonStyle())
    }
}

private struct LibraryMetric: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        StudioPill(title: title, tint: tint, symbol: symbol)
    }
}
