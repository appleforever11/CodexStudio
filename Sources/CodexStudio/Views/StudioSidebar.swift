import SwiftUI

struct StudioSidebar: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 20)).foregroundStyle(StudioColor.spectrum)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Studio").font(.system(size: 23, weight: .semibold))
                            Text("Make it yours").font(.system(size: 11)).foregroundStyle(StudioColor.textMuted)
                        }
                    }.padding(.horizontal, 12).padding(.top, 10)

                    VStack(spacing: 4) {
                        navigation("Canvas", symbol: "rectangle.inset.filled", selected: store.section == .canvas) { store.selectSection(.canvas) }
                        navigation("Explore", symbol: "square.grid.2x2", selected: store.section == .themes && store.themeFilter == .all && store.selectedThemeCategory == "All") { store.selectThemes() }
                        navigation("Live editor", symbol: "slider.horizontal.3", selected: store.section == .editor) { store.selectSection(.editor) }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        sectionLabel("Collection")
                        navigation("Abstract", symbol: "play.rectangle", selected: store.section == .abstract) { store.selectSection(.abstract) }
                        navigation("Favorites", symbol: "star", count: store.favoriteCount, selected: store.section == .themes && store.themeFilter == .favorites) { store.selectFavorites() }
                        navigation("Recently used", symbol: "clock", selected: store.section == .themes && store.themeFilter == .recent) { store.selectRecent() }
                        navigation("Local library", symbol: "internaldrive", selected: store.section == .library) { store.selectSection(.library) }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        sectionLabel("Apple wallpapers")
                        ForEach(StudioPlatform.allCases) { platform in
                            navigation(platform.rawValue, symbol: platform.symbol,
                                selected: store.section == .themes && store.themeFilter == .all && store.selectedThemeCategory == platform.category) {
                                    store.selectPlatform(platform)
                                }
                        }
                    }
                }.padding(.horizontal, 12).padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity, alignment: .top)
            if let theme = store.selectedTheme {
                SidebarNowPlaying(theme: theme, artworkHeight: geometry.size.height < 760 ? 72 : 128)
                    .padding(.horizontal, 12).padding(.bottom, 12)
            }
            connectionFooter
        }
        .foregroundStyle(StudioColor.text)
        .background(.ultraThinMaterial)
        .frame(maxHeight: .infinity, alignment: .top)
        .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(StudioColor.textMuted)
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 5)
    }

    private func navigation(_ title: String, symbol: String, count: Int? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: symbol).font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .frame(width: 22, height: 24)
                    .foregroundStyle(selected ? StudioColor.cyan : StudioColor.textMuted)
                Text(title).font(.system(size: 12, weight: selected ? .semibold : .medium))
                Spacer(minLength: 0)
                if let count, count > 0 {
                    Text(count.formatted()).font(.system(size: 10, weight: .medium)).foregroundStyle(StudioColor.textMuted)
                }
            }
            .padding(.horizontal, 12).frame(height: 34)
            .background(selected ? StudioColor.cyan.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 11))
            .overlay {
                if selected { RoundedRectangle(cornerRadius: 11).strokeBorder(StudioColor.cyan.opacity(0.18), lineWidth: 1) }
            }
            .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(StudioPressableButtonStyle())
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityIdentifier("sidebar.\(title)")
    }

    private var connectionFooter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                StatusDot(color: store.connectionColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.isApplying ? "Applying theme…" : store.runtime.connection.label)
                        .font(.system(size: 11, weight: .semibold))
                    Text(store.runtime.codexVersion.map { "Codex \($0)" } ?? "Codex runtime")
                        .font(.system(size: 9)).foregroundStyle(StudioColor.textMuted).lineLimit(1)
                }
                Spacer()
                Button { store.selectSection(.settings) } label: {
                    Image(systemName: "gearshape").frame(width: 24, height: 28)
                        .foregroundStyle(store.section == .settings ? StudioColor.cyan : StudioColor.textMuted)
                }.buttonStyle(.plain).help("Settings").accessibilityLabel("Settings")
                Button { store.refreshRuntime() } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 28, height: 28)
                }.buttonStyle(.plain).help("Refresh connection")
                    .disabled(store.isRefreshingRuntime || store.isApplying)
                    .accessibilityLabel("Refresh connection")
            }
            StudioActionButton(title: store.isOpeningCodex ? "Opening…" : "Open themed Codex",
                symbol: "arrow.up.forward.app", busy: store.isOpeningCodex, compact: true) { store.openCodex() }
                .disabled(store.isOpeningCodex || store.isApplying).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 14)
        .overlay(alignment: .top) { Rectangle().fill(StudioColor.line).frame(height: 1) }
    }
}
