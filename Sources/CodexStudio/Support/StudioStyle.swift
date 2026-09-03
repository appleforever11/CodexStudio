import AppKit
import SwiftUI

/// A restrained, system-adjacent palette for the Studio shell. Theme artwork
/// supplies the personality; this chrome stays quiet enough to keep controls
/// legible over any of the bundled worlds.
enum StudioColor {
    // Keep the shell responsive to the user's macOS appearance while the
    // accent colors remain part of Studio's visual identity.
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let ink = Color(hex: "#0A0B10")
    static let inkRaised = Color(nsColor: .controlBackgroundColor)
    static let inkSoft = Color(nsColor: .underPageBackgroundColor)
    static let text = Color(nsColor: .labelColor)
    static let textMuted = Color(nsColor: .secondaryLabelColor)
    static let textFaint = Color(nsColor: .tertiaryLabelColor)
    static let line = Color(nsColor: .separatorColor).opacity(0.52)
    static let lineStrong = Color(nsColor: .separatorColor)
    static let cyan = Color(hex: "#9CC7FF")
    static let violet = Color(hex: "#BCA8FF")
    static let orchid = Color(hex: "#E9A9D6")
    static let mint = Color(hex: "#92DDB6")
    static let amber = Color(hex: "#E9BB72")

    static let spectrum = LinearGradient(
        colors: [cyan, violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum StudioLayoutMetrics {
    static let sidebarWidth: CGFloat = 248
    static let windowHeaderHeight: CGFloat = 36
    static let pageHorizontalPadding: CGFloat = 28
    static let pageVerticalPadding: CGFloat = 26
    static let canvasHeroHeight: CGFloat = 334
    static let canvasHeroMinimumHeight: CGFloat = 270
    static let cardArtworkAspectRatio: CGFloat = 1.55
}

struct StudioPanelModifier: ViewModifier {
    var radius: CGFloat = 18
    var fill: Color = StudioColor.inkRaised.opacity(0.62)

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .background(fill, in: shape)
            .background(.thinMaterial, in: shape)
            .overlay {
                shape
                    .strokeBorder(StudioColor.line, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

/// Adds a small, consistent pressed state to custom Studio controls while
/// leaving native bordered controls to use their platform-provided treatment.
struct StudioPressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.76 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

extension View {
    func studioPanel(radius: CGFloat = 18, fill: Color = StudioColor.inkRaised.opacity(0.62)) -> some View {
        modifier(StudioPanelModifier(radius: radius, fill: fill))
    }

    func studioHoverScale(_ isHovered: Bool) -> some View {
        modifier(StudioHoverModifier(isHovered: isHovered))
    }
}

private struct StudioHoverModifier: ViewModifier {
    let isHovered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.008 : 1))
            .offset(y: reduceMotion ? 0 : (isHovered ? -1 : 0))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isHovered)
    }
}

struct StudioIconButton: View {
    let symbol: String
    let help: String
    var tint = StudioColor.textMuted
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(StudioColor.line, lineWidth: 1)
                }
        }
        .buttonStyle(StudioPressableButtonStyle())
        .help(help)
    }
}

struct StudioPill: View {
    let title: String
    var tint: Color = StudioColor.textMuted
    var symbol: String?

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        }
    }
}

struct StatusDot: View {
    let color: Color
    var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.70), radius: isExpanded ? 7 : 3)
            .onAppear {
                guard isPulsing && !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                    isExpanded = true
                }
            }
    }
}
