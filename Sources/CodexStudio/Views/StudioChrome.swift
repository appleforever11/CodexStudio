import SwiftUI

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
