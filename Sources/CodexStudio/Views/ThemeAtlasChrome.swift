import SwiftUI

struct CatalogToolbar: View {
    @EnvironmentObject private var store: StudioStore
    var installedOnly = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(StudioColor.textMuted)
                    TextField("Search artwork, releases, collections", text: $store.searchText)
                        .textFieldStyle(.plain).font(.system(size: 12))
                        .accessibilityIdentifier("themes.search-field")
                    if !store.searchText.isEmpty {
                        Button { store.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12).frame(height: 38)
                .background(StudioColor.inkRaised.opacity(0.35), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(StudioColor.line, lineWidth: 1))

                Menu {
                    Picker("Sort themes", selection: Binding(get: { store.themeSortOrder }, set: store.setThemeSortOrder)) {
                        ForEach(ThemeSortOrder.allCases) { order in Text(order.label).tag(order) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down").frame(width: 34, height: 34)
                }
                .menuStyle(.borderlessButton).fixedSize().help("Sort themes")
                .accessibilityLabel("Sort themes")
                ThemeLayoutPicker()
            }

            HStack(spacing: 10) {
                if !installedOnly {
                    Picker("Collection", selection: $store.themeFilter) {
                        Text("All themes").tag(ThemeFilter.all)
                        Text("Favorites").tag(ThemeFilter.favorites)
                        Text("Recent").tag(ThemeFilter.recent)
                    }
                    .labelsHidden().frame(width: 132)
                }
                Picker("Category", selection: $store.selectedThemeCategory) {
                    ForEach(store.themeCategories, id: \.self) { category in
                        Text(category == "All" ? "All categories" : category).tag(category)
                    }
                }.labelsHidden().frame(width: 150)
                if !store.availableReleases.isEmpty {
                    Picker("Platform release", selection: $store.selectedReleaseID) {
                        Text("All releases").tag(String?.none)
                        ForEach(store.availableReleases, id: \.id) { release in
                            Text(release.displayName).tag(Optional(release.id))
                        }
                    }.labelsHidden().frame(maxWidth: 230)
                        .accessibilityIdentifier("themes.release-filter")
                }
                Spacer(minLength: 0)
                if !store.searchText.isEmpty || store.selectedReleaseID != nil {
                    Button("Reset") { store.searchText = ""; store.selectedReleaseID = nil }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(StudioColor.cyan)
                }
            }
            .font(.system(size: 11))
        }
        .padding(12)
        .studioGlass(radius: 18)
        .onChange(of: store.themeFilter) { _, _ in
            if !store.themeCategories.contains(store.selectedThemeCategory) { store.selectedThemeCategory = "All" }
            if !store.availableReleases.contains(where: { $0.id == store.selectedReleaseID }) { store.selectedReleaseID = nil }
        }
    }
}
