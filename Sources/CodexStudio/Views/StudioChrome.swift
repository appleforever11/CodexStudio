import SwiftUI

struct StudioWindowHeader: View {
    @EnvironmentObject private var store: StudioStore
    static let height: CGFloat = StudioLayoutMetrics.windowHeaderHeight

    var body: some View {
        HStack {
            Spacer()
            Text("Codex Studio")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StudioColor.textMuted)
            Spacer()
        }
        .frame(height: Self.height)
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
        .modifier(StudioWindowDragModifier())
    }
}

private struct StudioWindowDragModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.gesture(WindowDragGesture()).allowsWindowActivationEvents(true)
        } else { content }
    }
}

struct StudioBackdrop: View {
    let theme: Theme?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                StudioColor.canvas
                if let theme, !reduceTransparency {
                    ThemeArtworkView(theme: theme, showOverlay: false, maxPixelSize: 160)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped().blur(radius: 70).scaleEffect(1.15)
                        .opacity(colorScheme == .dark ? 0.55 : 0.18)
                }
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [StudioColor.ink.opacity(0.64), StudioColor.ink.opacity(0.72), StudioColor.ink.opacity(0.94)]
                        : [Color.white.opacity(0.62), Color.white.opacity(0.74), Color.white.opacity(0.91)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .ignoresSafeArea().allowsHitTesting(false)
    }
}
