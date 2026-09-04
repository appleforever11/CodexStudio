import SwiftUI

/// Glass is reserved for controls floating above artwork, not the artwork
/// itself. The fallback stays legible on older systems and with accessibility.
private struct StudioGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if reduceTransparency {
            content.background(StudioColor.inkRaised, in: shape)
                .overlay(shape.strokeBorder(StudioColor.lineStrong, lineWidth: 1))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 1))
        }
    }
}

extension View {
    func studioGlass(radius: CGFloat = 16) -> some View {
        modifier(StudioGlassModifier(radius: radius))
    }
}

struct StudioGlassGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { content }
        } else {
            content
        }
    }
}

struct StudioActionButton: View {
    let title: String
    let symbol: String
    var prominent = false
    var busy = false
    var compact = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            if prominent {
                label.foregroundStyle(StudioColor.ink)
                    .background(StudioColor.spectrum, in: Capsule())
            } else {
                label.foregroundStyle(StudioColor.text).studioGlass(radius: 24)
            }
        }
        .buttonStyle(StudioPressableButtonStyle())
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var label: some View {
        HStack(spacing: 7) {
            if busy { ProgressView().controlSize(.small) }
            else { Image(systemName: symbol) }
            Text(title).lineLimit(1)
        }
        .font(.system(size: compact ? 11 : 12, weight: .semibold))
        .padding(.horizontal, compact ? 12 : 18)
        .frame(height: compact ? 32 : 40)
        .contentShape(Capsule())
    }
}

struct ThemeFavoriteButton: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme

    var body: some View {
        Button { store.toggleFavorite(theme) } label: {
            Image(systemName: theme.isFavorite ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.isFavorite ? StudioColor.amber : .white)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(StudioPressableButtonStyle())
        .studioGlass(radius: 18)
        .environment(\.colorScheme, .dark)
        .help(theme.isFavorite ? "Remove from Favorites" : "Add to Favorites")
        .accessibilityLabel("\(theme.isFavorite ? "Remove" : "Add") \(theme.name) \(theme.isFavorite ? "from" : "to") favorites")
        .accessibilityValue(theme.isFavorite ? "Saved" : "Not saved")
        .accessibilityIdentifier("theme-card.\(theme.id).favorite")
    }
}

struct StudioSectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 23, weight: .bold)).foregroundStyle(StudioColor.text)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail).font(.system(size: 12)).foregroundStyle(StudioColor.textMuted)
            }
        }
    }
}
