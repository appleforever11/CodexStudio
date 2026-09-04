import SwiftUI

struct ThemeAtlasRow: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme
    let isSelected: Bool
    private var active: Bool { store.runtime.activeThemeID == theme.id }

    var body: some View {
        HStack(spacing: 16) {
            Button { store.selectTheme(theme) } label: {
                HStack(spacing: 16) {
                    Color.clear.frame(width: 150, height: 92)
                        .overlay {
                            ThemeArtworkView(theme: theme, showOverlay: false, maxPixelSize: 450)
                                .frame(width: 150, height: 92)
                        }.clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 7) {
                        Text(theme.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(StudioColor.text).lineLimit(1)
                        Text(theme.platformRelease?.displayName ?? theme.category)
                            .font(.system(size: 11)).foregroundStyle(StudioColor.textMuted).lineLimit(1)
                        Text(active ? "Active in Codex" : (theme.isInstalled ? "Available offline" : "Preview"))
                            .font(.system(size: 10)).foregroundStyle(active ? StudioColor.mint : StudioColor.textMuted)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Preview \(theme.name)")
            ThemeFavoriteButton(theme: theme)
            StudioIconButton(symbol: active ? "checkmark" : "arrow.up.right", help: "Apply \(theme.name)") {
                store.selectTheme(theme)
                store.applySelectedTheme()
            }.disabled(!store.canApply || active || !theme.isInstalled)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).strokeBorder(isSelected ? StudioColor.cyan.opacity(0.75) : StudioColor.line,
                lineWidth: isSelected ? 1.5 : 1).allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }
}
