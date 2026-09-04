import SwiftUI

struct CanvasPage: View {
    @EnvironmentObject private var store: StudioStore

    private var savedThemes: [Theme] {
        Array(store.themes.filter(\.isFavorite).prefix(8))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    HStack {
                        StudioSectionHeading(title: "Your canvas", detail: "A space that feels like you.")
                        Spacer()
                        StudioActionButton(title: "Explore themes", symbol: "square.grid.2x2") { store.selectThemes() }
                    }
                    if let theme = store.selectedTheme {
                        ThemeHero(theme: theme, height: min(520, max(380, geometry.size.width * 0.38)))
                    } else if store.isLoading {
                        ThemeAtlasLoadingState(title: "Preparing your canvas", detail: "Reading your local artwork library…")
                            .frame(height: 380)
                    } else {
                        ThemeAtlasErrorState(title: "Your canvas is waiting", detail: store.libraryError ?? "Import a theme to get started.",
                            retry: { Task { await store.bootstrap(force: true) } }).frame(height: 380)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        shelfHeading("The Apple collection", detail: "Explore by platform and release")
                        HStack(spacing: 16) {
                            ForEach(StudioPlatform.allCases) { platform in
                                PlatformCollectionCard(platform: platform,
                                    themes: store.themes.filter { $0.category == platform.category })
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            shelfHeading(savedThemes.isEmpty ? "Recently explored" : "Made for your favorites",
                                detail: savedThemes.isEmpty ? "Pick up where you left off" : "Your personal collection, always close")
                            Spacer()
                            Button("View all", systemImage: "arrow.right") {
                                if savedThemes.isEmpty { store.selectRecent() } else { store.selectFavorites() }
                            }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(StudioColor.cyan)
                        }
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 16) {
                                ForEach(savedThemes.isEmpty ? store.recentThemes : savedThemes) { theme in
                                    ThemeAtlasCard(theme: theme, isSelected: store.selectedThemeID == theme.id).frame(width: 280)
                                }
                            }.padding(.vertical, 3)
                        }.scrollIndicators(.hidden)
                        if savedThemes.isEmpty && store.recentThemes.isEmpty {
                            Text("Select an artwork to start exploring. Star the ones you love to keep them here.")
                                .font(.callout).foregroundStyle(.secondary).padding(.vertical, 12)
                        }
                    }
                    Label("\(store.themes.count) themes in your local library · No streaming required", systemImage: "internaldrive")
                        .font(.system(size: 11)).foregroundStyle(StudioColor.textMuted)
                }
                .padding(StudioLayoutMetrics.pageHorizontalPadding)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("page.canvas")
    }

    private func shelfHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(StudioColor.text)
            Text(detail).font(.system(size: 11)).foregroundStyle(StudioColor.textMuted)
        }
    }
}

struct PlatformCollectionCard: View {
    @EnvironmentObject private var store: StudioStore
    let platform: StudioPlatform
    let themes: [Theme]

    private var cover: Theme? {
        let preferred = platform == .macOS ? "Big Sur" : platform == .iPadOS ? "Noodles Pink Dark" : "Earth"
        return themes.first { $0.name == preferred } ?? themes.first
    }

    var body: some View {
        Button { store.selectPlatform(platform) } label: {
            Color.clear.frame(height: 160)
                .overlay {
                    GeometryReader { geometry in
                        if let cover {
                            ThemeArtworkView(theme: cover, showOverlay: false, maxPixelSize: 700)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                }
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.76)], startPoint: .top, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 5) {
                            Label(platform.rawValue, systemImage: platform.symbol).font(.system(size: 19, weight: .semibold))
                            Text("\(themes.count) wallpapers").font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold))
                    }.padding(18).foregroundStyle(.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(StudioPressableButtonStyle())
        .accessibilityLabel("Browse \(platform.rawValue), \(themes.count) wallpapers")
    }
}
