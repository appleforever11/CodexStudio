import SwiftUI

/// Platform navigation stays independent of release filtering and result rendering.
struct CatalogPlatformStrip: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                platformButton("All artwork", symbol: "square.grid.2x2", selected: store.selectedThemeCategory == "All") {
                    store.selectThemes()
                }
                ForEach(StudioPlatform.allCases) { platform in
                    platformButton(platform.rawValue, symbol: platform.symbol,
                                   selected: store.selectedThemeCategory == platform.category) {
                        store.selectPlatform(platform)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func platformButton(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .foregroundStyle(selected ? StudioColor.cyan : StudioColor.textMuted)
                .background(selected ? StudioColor.cyan.opacity(0.14) : Color.white.opacity(0.025), in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? StudioColor.cyan.opacity(0.3) : StudioColor.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "")
    }
}
