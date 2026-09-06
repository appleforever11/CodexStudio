import SwiftUI

struct SidebarNowPlaying: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme
    var artworkHeight: CGFloat = 128
    private var active: Bool { store.runtime.activeThemeID == theme.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(active ? "Now playing" : "In preview").font(.system(size: 10, weight: .semibold))
                Spacer()
                Image(systemName: active ? "waveform" : "viewfinder").foregroundStyle(active ? StudioColor.mint : StudioColor.textMuted)
            }.foregroundStyle(StudioColor.textMuted)
            Button { store.selectSection(.canvas) } label: {
                Color.clear.frame(height: artworkHeight)
                    .overlay {
                        GeometryReader { geometry in
                            ThemeArtworkView(theme: theme, showOverlay: false, maxPixelSize: 500)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }.clipShape(RoundedRectangle(cornerRadius: 13))
            }.buttonStyle(.plain).accessibilityLabel("Show \(theme.name) on Canvas")
            Text(theme.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            StudioActionButton(title: active ? "Applied" : "Apply selection", symbol: active ? "checkmark" : "sparkles",
                prominent: true, busy: store.isApplying, compact: true) { store.applySelectedTheme() }
                .disabled(!store.canApply || active || !theme.isInstalled)
                .frame(maxWidth: .infinity)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(StudioColor.line, lineWidth: 1))
    }
}
