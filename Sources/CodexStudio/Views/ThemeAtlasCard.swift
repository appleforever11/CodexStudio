import SwiftUI

struct ThemeAtlasCard: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme
    let isSelected: Bool
    @State private var isHovered = false

    private var themeAccent: Color { Color(hex: theme.palette.accent) }
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            artwork
            metadata
        }
        .background(Color.white.opacity(isSelected ? 0.075 : isHovered ? 0.055 : 0.035), in: cardShape)
        .background(.thinMaterial, in: cardShape)
        .overlay {
            cardShape
                .strokeBorder(
                    isSelected ? themeAccent.opacity(0.82) : (isHovered ? StudioColor.lineStrong : StudioColor.line),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .shadow(
            color: isSelected ? themeAccent.opacity(0.16) : .black.opacity(isHovered ? 0.18 : 0.09),
            radius: isSelected ? 20 : 12,
            y: 8
        )
        .studioHoverScale(isHovered)
        .contentShape(cardShape)
        .onTapGesture {
            store.selectTheme(theme)
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(theme.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                store.toggleFavorite(theme)
            }
            if theme.isInstalled {
                Button("Apply to Codex") {
                    store.selectTheme(theme)
                    store.applySelectedTheme()
                }
            }
            Button("Open in Live Lab") {
                store.selectTheme(theme)
                store.selectSection(.editor)
            }
            if let sourceURL = theme.sourceURL.flatMap(URL.init(string:)) {
                Button("View artwork source") {
                    NSWorkspace.shared.open(sourceURL)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(theme.name), \(theme.category), \(theme.isInstalled ? "installed" : "preview")")
    }

    private var artwork: some View {
        ZStack(alignment: .topLeading) {
            ThemeArtworkView(theme: theme, animated: isHovered && store.motionEnabled, showOverlay: false)
            LinearGradient(
                colors: [.black.opacity(0.10), .clear, .black.opacity(0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(alignment: .top, spacing: 6) {
                Text(theme.category)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(.black.opacity(0.28), in: Capsule())

                Spacer(minLength: 0)

                if store.runtime.activeThemeID == theme.id {
                    Label("Active", systemImage: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(StudioColor.mint)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(.black.opacity(0.30), in: Capsule())
                } else if theme.isInstalled {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 24, height: 24)
                        .background(.black.opacity(0.28), in: Circle())
                }

                Button {
                    store.toggleFavorite(theme)
                } label: {
                    Image(systemName: theme.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.isFavorite ? StudioColor.amber : .white.opacity(0.88))
                        .frame(width: 24, height: 24)
                        .background(.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(StudioPressableButtonStyle())
                .accessibilityLabel(theme.isFavorite ? "Remove \(theme.name) from favorites" : "Add \(theme.name) to favorites")
            }
            .padding(10)
        }
        .frame(height: 176)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
    }

    private var metadata: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(theme.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    ThemeSwatch(theme: theme, size: 17)
                    Image(systemName: theme.isCurated ? "checkmark.seal.fill" : "internaldrive")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.isCurated ? StudioColor.mint : StudioColor.textFaint)
                    Text(theme.collection)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(StudioColor.textFaint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if theme.isInstalled {
                Button {
                    store.selectTheme(theme)
                    store.applySelectedTheme()
                } label: {
                    Image(systemName: store.runtime.activeThemeID == theme.id ? "checkmark" : "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(store.runtime.activeThemeID == theme.id ? StudioColor.mint : themeAccent)
                        .frame(width: 30, height: 30)
                        .background(themeAccent.opacity(0.10), in: Circle())
                        .overlay {
                            Circle().strokeBorder(themeAccent.opacity(0.24), lineWidth: 1)
                        }
                }
                .buttonStyle(StudioPressableButtonStyle())
                .disabled(store.isApplying)
                .help("Apply \(theme.name)")
                .accessibilityLabel("Apply \(theme.name)")
            }
        }
        .padding(14)
        .frame(minHeight: 78)
    }
}

struct ThemeAtlasEmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(StudioColor.cyan.opacity(0.10))
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(StudioColor.cyan)
            }
            .frame(width: 54, height: 54)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudioColor.text)
            Text(detail)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(StudioColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .studioPanel(radius: 18, fill: Color.white.opacity(0.025))
    }
}

struct ThemeAtlasLoadingState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .tint(StudioColor.cyan)
                .frame(width: 54, height: 54)
                .background(StudioColor.cyan.opacity(0.10), in: Circle())
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudioColor.text)
            Text(detail)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(StudioColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .studioPanel(radius: 18, fill: Color.white.opacity(0.025))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }
}
