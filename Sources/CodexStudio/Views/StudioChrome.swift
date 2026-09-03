import SwiftUI

struct StudioWindowHeader: View {
    static let height: CGFloat = StudioLayoutMetrics.windowHeaderHeight

    var body: some View {
        ZStack {
            // This is intentionally the same quiet material language used by
            // the sidebar and the page surface. The native traffic lights sit
            // over this background, making the window read as one bar rather
            // than a system strip followed by an app strip.
            Rectangle()
                .fill(.thinMaterial)

            LinearGradient(
                colors: [
                    StudioColor.inkRaised.opacity(0.34),
                    StudioColor.inkSoft.opacity(0.18),
                    StudioColor.inkRaised.opacity(0.28)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            Text("Codex Studio")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(StudioColor.textMuted)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .contentShape(Rectangle())
        .modifier(StudioWindowDragModifier())
    }
}

private struct StudioWindowDragModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
        } else {
            content
        }
    }
}

struct StudioBackdrop: View {
    let theme: Theme?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            StudioColor.canvas

            if let theme {
                ThemeArtworkView(theme: theme, animated: false, showOverlay: false)
                    .scaleEffect(1.26)
                    .blur(radius: 70)
                    .saturation(1.10)
                    .opacity(colorScheme == .dark
                        ? (theme.appearance == "light" ? 0.13 : 0.22)
                        : 0.08)
            }

            LinearGradient(
                colors: colorScheme == .dark
                    ? [StudioColor.ink.opacity(0.82), StudioColor.ink.opacity(0.68), StudioColor.ink.opacity(0.92)]
                    : [Color.white.opacity(0.82), Color.white.opacity(0.68), Color.white.opacity(0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let theme {
                RadialGradient(
                    colors: [Color(hex: theme.palette.accent).opacity(colorScheme == .dark ? 0.12 : 0.08), .clear],
                    center: .topTrailing,
                    startRadius: 30,
                    endRadius: 620
                )
            }
        }
        .ignoresSafeArea()
    }
}
