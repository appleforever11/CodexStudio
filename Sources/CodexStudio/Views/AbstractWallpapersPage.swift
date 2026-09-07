import SwiftUI

struct AbstractWallpapersPage: View {
    @EnvironmentObject private var store: StudioStore
    @State private var items: [AbstractWallpaper] = []
    @State private var search = ""
    @State private var busyID: String?
    @State private var message: String?
    private var filtered: [AbstractWallpaper] {
        search.isEmpty ? items : items.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Abstract").font(.largeTitle.bold())
                    Text("MoeWalls · \(items.count) live wallpapers").foregroundStyle(.secondary)
                    Text("Experimental animation · Import a preview loop, then apply from your local library.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Link("Browse source", destination: URL(string: "https://moewalls.com/category/abstract/")!)
            }
            TextField("Search Abstract wallpapers", text: $search).textFieldStyle(.roundedBorder)
            if let message { Text(message).font(.callout).textSelection(.enabled) }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 16)], spacing: 16) {
                    ForEach(filtered) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            AsyncImage(url: item.thumbnail) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() }
                                else { Rectangle().fill(.quaternary).overlay(Image(systemName: "photo")) }
                            }
                            .frame(height: 140).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                            Text(item.name).font(.headline).lineLimit(2).frame(height: 38, alignment: .top)
                            HStack {
                                Button(busyID == item.id ? "Importing…" : "Import animation") { importItem(item) }
                                    .disabled(busyID != nil)
                                Spacer()
                                Link(destination: item.url) { Image(systemName: "arrow.up.right.square") }
                                    .help("View creator and original wallpaper")
                            }
                        }.padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            Text("Catalog checked September 7, 2026 · Previews belong to their original creators. Imports are local and for personal use.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24)
        .task {
            do { items = try AbstractCatalog.load().items }
            catch { message = "The Abstract catalog could not be loaded: \(error.localizedDescription)" }
        }
    }
    private func importItem(_ item: AbstractWallpaper) {
        busyID = item.id
        message = "Downloading and preparing \(item.name)…"
        Task {
            defer { busyID = nil }
            do {
                let id = try await AbstractWallpaperService.importAnimation(item)
                await store.bootstrap(force: true)
                if let theme = store.themes.first(where: { $0.id == id }) { store.selectTheme(theme) }
                message = "Imported \(item.name). Open Local library to preview and apply it."
            } catch { message = error.localizedDescription }
        }
    }
}
