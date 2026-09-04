import SwiftUI

struct ThemeAtlasCard: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme
    let isSelected: Bool
    @State private var isHovered = false

    private var active: Bool { store.runtime.activeThemeID == theme.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A real selection button behind sibling controls: favoriting never
            // falls through to selection, applying, or the card's context menu.
            Button { store.selectTheme(theme) } label: {
                Color.clear.aspectRatio(1.42, contentMode: .fit)
                    .overlay {
                        GeometryReader { geometry in
                            ThemeArtworkView(theme: theme, showOverlay: false, maxPixelSize: 900)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                    .clipped()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview \(theme.name)")
            .accessibilityIdentifier("theme-card.\(theme.id).select")
            .overlay(alignment: .topLeading) {
                if active {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).frame(height: 30)
                        .studioGlass(radius: 16).environment(\.colorScheme, .dark)
                        .padding(14).allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) { ThemeFavoriteButton(theme: theme).padding(14) }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 21, topTrailingRadius: 21))

            HStack(spacing: 8) {
                Button { store.selectTheme(theme) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(theme.name).font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(StudioColor.text).lineLimit(1)
                        Text(theme.platformRelease?.displayName ?? theme.category)
                            .font(.system(size: 10)).foregroundStyle(StudioColor.textMuted).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Button {
                    store.selectTheme(theme)
                    store.applySelectedTheme()
                } label: {
                    Image(systemName: active ? "checkmark.circle.fill" : "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(active ? StudioColor.mint : StudioColor.textMuted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(!store.canApply || !theme.isInstalled || active)
                .help(active ? "Active in Codex" : "Apply \(theme.name)")
                .accessibilityLabel("Apply \(theme.name)")
                .accessibilityIdentifier("theme-card.\(theme.id).apply")
            }
            .padding(16)
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 21))
        .overlay {
            RoundedRectangle(cornerRadius: 21)
                .strokeBorder(isSelected ? StudioColor.cyan.opacity(0.8) : .white.opacity(isHovered ? 0.24 : 0.10),
                    lineWidth: isSelected ? 1.5 : 1)
                .allowsHitTesting(false)
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(theme.isFavorite ? "Remove from Favorites" : "Add to Favorites") { store.toggleFavorite(theme) }
            Button("Customize in Live Editor") { store.selectTheme(theme, openEditor: true) }
            if let url = theme.sourceURL.flatMap(URL.init(string:)), ["https", "http"].contains(url.scheme ?? "") {
                Link("View artwork source", destination: url)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("theme-card.\(theme.id)")
    }
}

struct ThemeAtlasEmptyState: View {
    let title: String
    let detail: String
    var symbol = "sparkle.magnifyingglass"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(StudioColor.cyan)
                .frame(width: 64, height: 64).studioGlass(radius: 22)
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(StudioColor.text)
            Text(detail).font(.system(size: 12)).foregroundStyle(StudioColor.textMuted).multilineTextAlignment(.center)
        }
        .padding(28).frame(maxWidth: .infinity)
    }
}

struct ThemeAtlasLoadingState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(title).font(.system(size: 16, weight: .semibold))
            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
