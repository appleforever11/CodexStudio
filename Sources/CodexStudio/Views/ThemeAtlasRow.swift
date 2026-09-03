import AppKit
import SwiftUI

struct ThemeAtlasRow: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme
    let isSelected: Bool
    @State private var isHovered = false

    private var themeAccent: Color { Color(hex: theme.palette.accent) }
    private var rowShape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
    private var releaseLabel: String { theme.platformRelease?.displayName ?? theme.collection }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                store.selectTheme(theme)
            } label: {
                ThemeArtworkView(theme: theme, showOverlay: false)
                    .frame(width: 128, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(StudioPressableButtonStyle())
            .help("Select \(theme.name)")

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(theme.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(StudioColor.text)
                        .lineLimit(1)
                    if store.runtime.activeThemeID == theme.id {
                        StudioPill(title: "Active", tint: StudioColor.mint, symbol: "checkmark")
                    }
                }

                Text(theme.shortDescription)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(StudioColor.textMuted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    ThemeSwatch(theme: theme, size: 16)
                    Text(theme.category)
                    Text("·")
                    Text(releaseLabel)
                    Text("·")
                    Text(theme.isInstalled ? "Installed" : "Preview")
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(StudioColor.textFaint)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                favoriteButton
                if theme.isInstalled {
                    applyButton
                }
            }
        }
        .padding(10)
        .background(
            isSelected ? themeAccent.opacity(0.11) : Color.white.opacity(isHovered ? 0.055 : 0.032),
            in: rowShape
        )
        .background(.thinMaterial, in: rowShape)
        .overlay {
            rowShape.strokeBorder(
                isSelected ? themeAccent.opacity(0.68) : (isHovered ? StudioColor.lineStrong : StudioColor.line),
                lineWidth: isSelected ? 1.5 : 1
            )
        }
        .studioHoverScale(isHovered)
        .contentShape(rowShape)
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
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(theme.name), \(theme.category), \(theme.isInstalled ? "installed" : "preview")")
        .accessibilityHint("Select this theme. Use the star to save it to Favorites.")
    }

    private var favoriteButton: some View {
        Button {
            store.toggleFavorite(theme)
        } label: {
            Image(systemName: theme.isFavorite ? "star.fill" : "star")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.isFavorite ? StudioColor.amber : StudioColor.textMuted)
                .frame(width: 30, height: 30)
                .background(theme.isFavorite ? StudioColor.amber.opacity(0.16) : Color.white.opacity(0.045), in: Circle())
                .overlay(Circle().strokeBorder(theme.isFavorite ? StudioColor.amber.opacity(0.48) : StudioColor.line, lineWidth: 1))
        }
        .buttonStyle(StudioPressableButtonStyle())
        .help(theme.isFavorite ? "Remove from Favorites" : "Add to Favorites")
        .accessibilityLabel(theme.isFavorite ? "Remove \(theme.name) from favorites" : "Add \(theme.name) to favorites")
        .accessibilityValue(theme.isFavorite ? "Saved" : "Not saved")
    }

    private var applyButton: some View {
        Button {
            store.selectTheme(theme)
            store.applySelectedTheme()
        } label: {
            Image(systemName: store.runtime.activeThemeID == theme.id ? "checkmark" : "arrow.up.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(store.runtime.activeThemeID == theme.id ? StudioColor.mint : themeAccent)
                .frame(width: 30, height: 30)
                .background(themeAccent.opacity(0.10), in: Circle())
                .overlay(Circle().strokeBorder(themeAccent.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(StudioPressableButtonStyle())
        .disabled(store.isApplying)
        .help("Apply \(theme.name)")
        .accessibilityLabel("Apply \(theme.name)")
    }
}
