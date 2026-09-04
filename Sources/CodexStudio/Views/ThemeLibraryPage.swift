import SwiftUI

struct ThemesPage: View {
    var body: some View { StudioCatalogPage(installedOnly: false) }
}

struct LibraryPage: View {
    var body: some View { StudioCatalogPage(installedOnly: true) }
}

private struct StudioCatalogPage: View {
    @EnvironmentObject private var store: StudioStore
    @AppStorage("studio.catalogPreviewVisible") private var showPreview = true
    let installedOnly: Bool

    private var title: String {
        if installedOnly { return "Local library" }
        if store.themeFilter == .favorites { return "Favorites" }
        if store.themeFilter == .recent { return "Recently used" }
        if store.selectedThemeCategory == "macOS Era" { return "macOS" }
        return store.selectedThemeCategory == "All" ? "Explore" : store.selectedThemeCategory
    }

    private var subtitle: String {
        if store.themeFilter == .favorites { return "The themes you love, together in one place." }
        if store.themeFilter == .recent { return "Your last eight selections, newest first." }
        if installedOnly { return "Your collection is stored on this Mac, ready offline." }
        return "Find a new perspective. Every selection starts as a preview."
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    StudioSectionHeading(title: title, detail: subtitle)
                    Spacer(minLength: 8)
                    if installedOnly {
                        StudioActionButton(title: "Import", symbol: "plus") { store.importThemeFolder() }
                        StudioIconButton(symbol: "folder", help: "Open local themes folder") { store.revealManagedThemes() }
                    }
                    Button { showPreview.toggle() } label: {
                        Image(systemName: showPreview ? "rectangle.topthird.inset.filled" : "rectangle")
                            .font(.system(size: 14)).frame(width: 36, height: 36)
                    }.buttonStyle(.plain).studioGlass(radius: 12)
                        .help(showPreview ? "Hide preview" : "Show preview")
                        .accessibilityLabel(showPreview ? "Hide preview" : "Show preview")
                }
                CatalogToolbar(installedOnly: installedOnly)
            }
            .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 16)

            ScrollViewReader { scroller in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Color.clear.frame(height: 0).id("catalog.top")
                    if showPreview, let theme = previewTheme {
                        ThemeHero(theme: theme, height: 300, compact: true)
                            .padding(.top, 8)
                    }
                    HStack {
                        Text("\(store.filteredThemes.count) \(store.filteredThemes.count == 1 ? "theme" : "themes")")
                            .font(.system(size: 12, weight: .semibold))
                        if let release = store.availableReleases.first(where: { $0.id == store.selectedReleaseID }) {
                            Text("· \(release.displayName)").font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if store.isScanningLibrary { ProgressView().controlSize(.small) }
                        else { Label("Available offline", systemImage: "internaldrive").font(.system(size: 10)).foregroundStyle(.secondary) }
                    }
                    catalogContent
                }
                .padding(.horizontal, 28).padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .onChange(of: filterKey) { _, _ in scroller.scrollTo("catalog.top", anchor: .top) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(installedOnly ? "page.library" : "page.explore")
    }

    private var previewTheme: Theme? {
        if let selected = store.selectedTheme, store.filteredThemes.contains(where: { $0.id == selected.id }) { return selected }
        return store.filteredThemes.first
    }

    private var filterKey: [String] {
        [store.themeFilter.rawValue, store.selectedThemeCategory, store.selectedReleaseID ?? "",
         store.searchText, store.themeSortOrder.rawValue, String(showPreview)]
    }

    @ViewBuilder private var catalogContent: some View {
        if store.isLoading && store.themes.isEmpty {
            ThemeAtlasLoadingState(title: "Opening your library", detail: "Loading local artwork…").frame(height: 260)
        } else if let error = store.libraryError, store.themes.isEmpty {
            ThemeAtlasErrorState(title: "Library unavailable", detail: error,
                retry: { Task { await store.bootstrap(force: true) } }).frame(height: 260)
        } else if store.filteredThemes.isEmpty {
            VStack(spacing: 14) {
                ThemeAtlasEmptyState(title: store.themeFilter == .favorites ? "Your next favorite is waiting" : "No matching themes",
                    detail: store.themeFilter == .favorites ? "Star a theme in Explore to save it here." : "Try a different search, platform, or release.",
                    symbol: store.themeFilter == .favorites ? "star" : "magnifyingglass")
                StudioActionButton(title: "Clear filters", symbol: "line.3.horizontal.decrease") { store.resetCatalogFilters() }
                if store.themeFilter == .favorites || store.themeFilter == .recent {
                    Button("Explore all themes") { store.selectThemes() }.buttonStyle(.plain).foregroundStyle(StudioColor.cyan)
                }
            }.frame(maxWidth: .infinity).padding(.vertical, 20)
        } else {
            ThemeCollectionView(themes: store.filteredThemes, layout: store.themeLayout)
        }
    }
}
