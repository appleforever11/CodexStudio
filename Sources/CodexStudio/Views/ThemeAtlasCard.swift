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
        // Keep the card discoverable as a selectable element while allowing
        // the nested favorite/apply buttons to remain independently clickable
        // in VoiceOver and in macOS's accessibility tree.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(theme.name), \(theme.category), \(theme.isInstalled ? "installed" : "preview")")
        .accessibilityHint("Select this theme. Use the star to save it to Favorites.")
        .accessibilityIdentifier("theme-card.\(theme.id)")
    }

    private var artwork: some View {
        ZStack {
            ThemeArtworkView(theme: theme, animated: isHovered && store.motionEnabled, showOverlay: false)
            LinearGradient(
                colors: [.black.opacity(0.10), .clear, .black.opacity(0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .aspectRatio(StudioLayoutMetrics.cardArtworkAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            categoryBadge
                .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                if store.runtime.activeThemeID == theme.id {
                    installedBadge(tint: StudioColor.mint, background: StudioColor.mint.opacity(0.18))
                } else if theme.isInstalled {
                    installedBadge(tint: .white.opacity(0.90), background: .black.opacity(0.38))
                }
                favoriteButton
            }
            .padding(12)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
    }

    private var categoryBadge: some View {
        Text(theme.category)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(.black.opacity(0.42), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
    }

    private func installedBadge(tint: Color, background: Color) -> some View {
        Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(background, in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(tint.opacity(0.34), lineWidth: 1)
            }
            .accessibilityLabel(store.runtime.activeThemeID == theme.id ? "Active in Codex" : "Installed")
    }

    private var favoriteButton: some View {
        Button {
            store.toggleFavorite(theme)
        } label: {
            Image(systemName: theme.isFavorite ? "star.fill" : "star")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.isFavorite ? StudioColor.amber : .white.opacity(0.92))
                .frame(width: 30, height: 30)
                .background(
                    theme.isFavorite ? StudioColor.amber.opacity(0.20) : .black.opacity(0.38),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            theme.isFavorite ? StudioColor.amber.opacity(0.58) : .white.opacity(0.22),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(StudioPressableButtonStyle())
        .accessibilityLabel(theme.isFavorite ? "Remove \(theme.name) from favorites" : "Add \(theme.name) to favorites")
        .accessibilityValue(theme.isFavorite ? "Saved" : "Not saved")
        .help(theme.isFavorite ? "Remove from Favorites" : "Add to Favorites")
        .contentShape(Circle())
        .zIndex(2)
        .accessibilityIdentifier("theme-card.\(theme.id).favorite")
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
                    Text(theme.platformRelease?.displayName ?? theme.collection)
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
                .accessibilityIdentifier("theme-card.\(theme.id).apply")
            }
        }
        .padding(14)
        .frame(minHeight: 78)
    }
}

struct ThemeAtlasEmptyState: View {
    let title: String
    let detail: String
    let symbol: String

    init(title: String, detail: String, symbol: String = "sparkle.magnifyingglass") {
        self.title = title
        self.detail = detail
        self.symbol = symbol
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(StudioColor.cyan.opacity(0.10))
                Image(systemName: symbol)
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
