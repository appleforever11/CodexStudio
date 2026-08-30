import SwiftUI

enum StudioColor {
    static let ink = Color(hex: "#080B12")
    static let inkRaised = Color(hex: "#101722")
    static let inkSoft = Color(hex: "#172131")
    static let text = Color(hex: "#F3F7FB")
    static let textMuted = Color(hex: "#98A7B8")
    static let textFaint = Color(hex: "#687789")
    static let line = Color.white.opacity(0.10)
    static let lineStrong = Color.white.opacity(0.17)
    static let cyan = Color(hex: "#7DD3FC")
    static let violet = Color(hex: "#B9A3FF")
}

struct StudioPanelModifier: ViewModifier {
    var radius: CGFloat = 20
    var fill: Color = StudioColor.inkRaised.opacity(0.72)

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(StudioColor.line, lineWidth: 1)
            }
    }
}

extension View {
    func studioPanel(radius: CGFloat = 20, fill: Color = StudioColor.inkRaised.opacity(0.72)) -> some View {
        modifier(StudioPanelModifier(radius: radius, fill: fill))
    }

    func studioHoverScale(_ isHovered: Bool) -> some View {
        scaleEffect(isHovered ? 1.012 : 1)
            .animation(.easeOut(duration: 0.18), value: isHovered)
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
                    .font(.system(size: 9, weight: .bold))
            }
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 1))
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
            .shadow(color: color.opacity(0.75), radius: isExpanded ? 7 : 3)
            .onAppear {
                guard isPulsing else { return }
                withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                    isExpanded = true
                }
            }
    }
}
