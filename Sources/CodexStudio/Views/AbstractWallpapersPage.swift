import SwiftUI

struct AbstractWallpapersPage: View {
    @EnvironmentObject private var store: StudioStore
    @State private var items: [AbstractWallpaper] = []
    @State private var search = ""
    @State private var busyID: String?
    @State private var message: String?
    @State private var selected: AbstractWallpaper?
    @State private var checked = ""
    @State private var refreshing = false
    private var filtered: [AbstractWallpaper] {
        search.isEmpty ? items : items.filter { $0.title.localizedCaseInsensitiveContains(search) }
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
            if let message { Text(message).font(.callout).textSelection(.enabled) }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 28)], spacing: 32) {
                    ForEach(filtered) { item in
                        Button { selected = item } label: {
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

            Text("Checked \(checked) · Refreshes weekly when opened. Saved catalog works offline. Personal use only.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24)
        .task {
            do { show(try await MoeCatalogService.shared.load()) }
            catch { message = error.localizedDescription }
            refresh(force: false)
        }
        .sheet(item: $selected) { item in
            AbstractWallpaperPreview(item: item) { option in
                selected = nil
                importItem(item, option: option)
            }
        }
    }
    private func show(_ catalog: AbstractCatalog) {
        items = catalog.items
        checked = String(catalog.retrievedAt.prefix(10))
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
        busyID = item.id
        message = "Downloading and preparing \(item.name) · \(option.label)…"
        Task {
            defer { busyID = nil }
            do {
                let id = try await AbstractWallpaperService.importAnimation(item, option: option)
                await store.bootstrap(force: true)
                if let theme = store.themes.first(where: { $0.id == id }) { store.selectTheme(theme) }
                message = "Imported \(item.name). Open Local library to preview and apply it."
            } catch { message = error.localizedDescription }
        }
    }
}
