import SwiftUI

struct StudioBackdrop: View {
    let theme: Theme?

    var body: some View {
        ZStack {
            StudioColor.ink

            if let theme {
                ThemeArtworkView(theme: theme, animated: false, showOverlay: false)
                    .scaleEffect(1.26)
                    .blur(radius: 70)
                    .saturation(1.10)
                    .opacity(theme.appearance == "light" ? 0.13 : 0.22)
            }

            LinearGradient(
                colors: [
                    StudioColor.ink.opacity(0.82),
                    StudioColor.ink.opacity(0.68),
                    StudioColor.ink.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let theme {
                RadialGradient(
                    colors: [Color(hex: theme.palette.accent).opacity(0.12), .clear],
                    center: .topTrailing,
                    startRadius: 30,
                    endRadius: 620
                )
            }
        }
        .ignoresSafeArea()
    }
}
