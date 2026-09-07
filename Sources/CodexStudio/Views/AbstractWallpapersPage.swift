import SwiftUI

struct AbstractWallpapersPage: View {
    @EnvironmentObject private var store: StudioStore
    @State private var items: [AbstractWallpaper] = []
    @State private var search = ""
    @State private var busyID: String?
    @State private var message: String?
    @State private var selected: AbstractWallpaper?
    @State private var previewError: String?
    @State private var checked = ""
    @State private var refreshing = false
    @State private var importedItemIDs = Set<String>()
    @State private var favoriteItemIDs = Set<String>()
    @AppStorage("CodexStudio.moeAbstractSort") private var sortRaw = AbstractSortOption.recommended.rawValue
    @AppStorage("CodexStudio.moeAbstractFilter") private var filterRaw = AbstractFilterOption.all.rawValue
    @AppStorage("CodexStudio.moeAbstractRecentIDs") private var recentIDsRaw = ""

    private var sortOption: AbstractSortOption {
        get { AbstractSortOption(rawValue: sortRaw) ?? .recommended }
        set { sortRaw = newValue.rawValue }
    }
    private var filterOption: AbstractFilterOption {
        get { AbstractFilterOption(rawValue: filterRaw) ?? .all }
        set { filterRaw = newValue.rawValue }
    }
    private var recentIDs: [String] {
        recentIDsRaw.split(separator: ",").map(String.init)
    }

    private var filtered: [AbstractWallpaper] {
        let matches = items.enumerated().filter { index, item in
            let matchesSearch = search.isEmpty || item.title.localizedCaseInsensitiveContains(search)
            let matchesFilter: Bool
            switch filterOption {
            case .all: matchesFilter = true
            case .imported: matchesFilter = isImported(item)
            case .favorites: matchesFilter = isFavorite(item)
            case .largePreview: matchesFilter = (item.previewWidth ?? 0) >= 1920
            }
            return matchesSearch && matchesFilter
        }
        return matches.sorted { lhs, rhs in
            switch sortOption {
            case .recommended:
                let leftFavorite = isFavorite(lhs.element)
                let rightFavorite = isFavorite(rhs.element)
                if leftFavorite != rightFavorite { return leftFavorite }
                let leftImported = isImported(lhs.element)
                let rightImported = isImported(rhs.element)
                if leftImported != rightImported { return leftImported }
                let leftRecent = recentRank(lhs.element)
                let rightRecent = recentRank(rhs.element)
                if leftRecent != rightRecent { return leftRecent < rightRecent }
                return lhs.offset < rhs.offset
            case .newest:
                return lhs.offset < rhs.offset
            case .name:
                return lhs.element.name.localizedStandardCompare(rhs.element.name) == .orderedAscending
            case .largestPreview:
                let leftWidth = lhs.element.previewWidth ?? 0
                let rightWidth = rhs.element.previewWidth ?? 0
                if leftWidth != rightWidth { return leftWidth > rightWidth }
                return lhs.offset < rhs.offset
            case .recentlyViewed:
                let leftRank = recentRank(lhs.element)
                let rightRank = recentRank(rhs.element)
                if leftRank != rightRank { return leftRank < rightRank }
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Abstract").font(.largeTitle.bold())
                    Text("MoeWalls · \(items.count) live wallpapers").foregroundStyle(.secondary)
                    Text("Click a wallpaper for a larger preview and download options.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button(refreshing ? "Refreshing…" : "Refresh catalog") { refresh(force: true) }.disabled(refreshing)
                Link("Browse source", destination: URL(string: "https://moewalls.com/category/abstract/")!)
            }
            TextField("Search Abstract wallpapers", text: $search).textFieldStyle(.roundedBorder)
            HStack(spacing: 12) {
                Picker("Sort", selection: Binding(
                    get: { AbstractSortOption(rawValue: sortRaw) ?? .recommended },
                    set: { sortRaw = $0.rawValue }
                )) {
                    ForEach(AbstractSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Sort Abstract wallpapers")

                Picker("Filter", selection: Binding(
                    get: { AbstractFilterOption(rawValue: filterRaw) ?? .all },
                    set: { filterRaw = $0.rawValue }
                )) {
                    ForEach(AbstractFilterOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Filter Abstract wallpapers")

                Text("\(filtered.count) of \(items.count)")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                if filterOption != .all || !search.isEmpty {
                    Button("Clear filters") {
                        search = ""
                        filterRaw = AbstractFilterOption.all.rawValue
                    }
                    .buttonStyle(.link)
                }
            }
            if let message { Text(message).font(.callout).textSelection(.enabled) }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 28)], spacing: 32) {
                    ForEach(filtered) { item in
                        Button { previewError = nil; markViewed(item); selected = item } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                Color.clear.aspectRatio(16 / 9, contentMode: .fit)
                                    .overlay {
                                        AsyncImage(url: item.thumbnail) { phase in
                                            if let image = phase.image { image.resizable().scaledToFill() }
                                            else { Rectangle().fill(.quaternary).overlay(Image(systemName: "photo")) }
                                        }
                                    }.clipped()
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .padding(10).studioGlass(radius: 20).padding(14)
                                    }
                                    .overlay(alignment: .topLeading) {
                                        HStack(spacing: 6) {
                                            if isImported(item) { abstractBadge("Imported", symbol: "internaldrive") }
                                            if (item.previewWidth ?? 0) >= 1920 {
                                                abstractBadge("Large preview", symbol: "sparkles")
                                            }
                                        }
                                        .padding(14)
                                    }
                                HStack(alignment: .top, spacing: 12) {
                                    Text(item.name).font(.headline).lineLimit(2)
                                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
                                    Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                                }.padding(20)
                            }
                            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.08)))
                            .contentShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                        .disabled(busyID != nil)
                        .accessibilityLabel("Preview \(item.name)")
                    }
                }.padding(.vertical, 8)
            }

            Text("Checked \(checked) · Recommended prioritizes favorites, imported wallpapers, and recent views. Saved catalog works offline.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24)
        .task {
            do { show(try await MoeCatalogService.shared.load()) }
            catch { message = error.localizedDescription }
            refresh(force: false)
        }
        .onChange(of: store.themes) { _, _ in
            rebuildLocalStatus()
        }
        .sheet(item: $selected) { item in
            AbstractWallpaperPreview(item: item, importError: previewError) { option in
                selected = nil
                importItem(item, option: option)
            }
        }
    }
    private func show(_ catalog: AbstractCatalog) {
        items = catalog.items
        checked = String(catalog.retrievedAt.prefix(10))
        rebuildLocalStatus()
    }

    private func rebuildLocalStatus() {
        var imported = Set<String>()
        var favorites = Set<String>()
        for item in items {
            let matching = store.themes.filter { theme in
                theme.id == item.id || theme.id.hasPrefix(item.id + "-")
            }
            guard !matching.isEmpty else { continue }
            imported.insert(item.id)
            if matching.contains(where: { $0.isFavorite }) { favorites.insert(item.id) }
        }
        importedItemIDs = imported
        favoriteItemIDs = favorites
    }

    private func isImported(_ item: AbstractWallpaper) -> Bool {
        importedItemIDs.contains(item.id)
    }

    private func isFavorite(_ item: AbstractWallpaper) -> Bool {
        favoriteItemIDs.contains(item.id)
    }

    private func recentRank(_ item: AbstractWallpaper) -> Int {
        recentIDs.firstIndex(of: item.id) ?? Int.max
    }

    private func markViewed(_ item: AbstractWallpaper) {
        var updated = recentIDs.filter { $0 != item.id }
        updated.insert(item.id, at: 0)
        recentIDsRaw = updated.prefix(20).joined(separator: ",")
    }

    private func abstractBadge(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 9).padding(.vertical, 6)
            .foregroundStyle(.white)
            .background(.black.opacity(0.52), in: Capsule())
    }
    private func refresh(force: Bool) {
        guard !refreshing else { return }
        refreshing = true
        Task {
            defer { refreshing = false }
            do {
                show(try await MoeCatalogService.shared.refresh(force: force))
                if force { message = "Catalog checked. Wallpaper downloads remain on demand." }
            } catch { message = "Could not refresh MoeWalls. Using the saved catalog. \(error.localizedDescription)" }
        }
    }
    private func importItem(_ item: AbstractWallpaper, option: MoeDownloadOption) {
        previewError = nil
        busyID = item.id
        message = "Downloading and preparing \(item.name) · \(option.label)…"
        Task {
            defer { busyID = nil }
            do {
                let id = try await AbstractWallpaperService.importAnimation(item, option: option)
                await store.bootstrap(force: true)
                if let theme = store.themes.first(where: { $0.id == id }) { store.selectTheme(theme) }
                message = "Imported \(item.name). Open Local library to preview and apply it."
            } catch {
                let detail = "\(option.label): \(error.localizedDescription)"
                message = detail
                previewError = detail
                selected = item
            }
        }
    }
}
