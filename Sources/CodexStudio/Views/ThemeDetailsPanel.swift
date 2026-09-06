import SwiftUI

/// Selection details remain separate from the artwork and its visual effects.
struct ThemeDetailsPanel: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("THE SELECTION", systemImage: "viewfinder")
                .font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary)
            Text(theme.name).font(.title2.weight(.semibold)).lineLimit(3)
            Text(theme.platformRelease?.displayName ?? theme.category)
                .font(.callout).foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                detail("Storage", value: theme.isInstalled ? "On this Mac" : "Not installed", symbol: "internaldrive")
                detail("Collection", value: theme.category, symbol: "square.stack")
                detail("Status", value: store.runtime.activeThemeID == theme.id ? "Active in Codex" : "Preview only", symbol: "circle.lefthalf.filled")
            }
            HStack(spacing: 8) {
                ForEach([theme.palette.accent, theme.palette.background, theme.palette.panel].indices, id: \.self) { index in
                    let color = [theme.palette.accent, theme.palette.background, theme.palette.panel][index]
                    Circle().fill(Color(hex: color)).frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                }
            }.accessibilityLabel("Theme interface palette")
            Spacer(minLength: 0)
            Text("Selecting artwork never changes Codex until you choose Apply.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(StudioColor.line))
    }

    private func detail(_ title: String, value: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 18).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption.weight(.medium))
            }
        }
    }
}

struct StudioCollectionSummary: View {
    let total: Int
    let favorites: Int
    let recent: Int
    var body: some View {
        HStack(spacing: 24) {
            metric(total, "artworks", "square.grid.2x2")
            metric(favorites, "favorites", "star")
            metric(recent, "recent", "clock")
            Spacer()
            Label("Local first", systemImage: "internaldrive").font(.caption).foregroundStyle(.secondary)
        }.padding(18).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
    private func metric(_ value: Int, _ label: String, _ symbol: String) -> some View {
        Label { Text("\(value.formatted()) ").bold() + Text(label).foregroundColor(.secondary) }
        icon: { Image(systemName: symbol).foregroundStyle(.secondary) }
        .font(.callout)
    }
}
