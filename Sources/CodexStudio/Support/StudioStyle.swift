import SwiftUI

/// A restrained, system-adjacent palette for the Studio shell. Theme artwork
/// supplies the personality; this chrome stays quiet enough to keep controls
/// legible over any of the bundled worlds.
enum StudioColor {
    static let ink = Color(hex: "#0A0B10")
    static let inkRaised = Color(hex: "#15171E")
    static let inkSoft = Color(hex: "#20232C")
    static let text = Color(hex: "#F5F5F7")
    static let textMuted = Color(hex: "#B4B7C0")
    static let textFaint = Color(hex: "#858994")
    static let line = Color.white.opacity(0.11)
    static let lineStrong = Color.white.opacity(0.20)
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

extension View {
    func studioPanel(radius: CGFloat = 18, fill: Color = StudioColor.inkRaised.opacity(0.62)) -> some View {
        modifier(StudioPanelModifier(radius: radius, fill: fill))
    }

    func studioHoverScale(_ isHovered: Bool) -> some View {
        scaleEffect(isHovered ? 1.008 : 1)
            .offset(y: isHovered ? -1 : 0)
            .animation(.easeOut(duration: 0.18), value: isHovered)
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
        .buttonStyle(.plain)
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
    @State private var isExpanded = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.70), radius: isExpanded ? 7 : 3)
            .onAppear {
                guard isPulsing else { return }
                withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                    isExpanded = true
                }
            }
    }
}
