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

struct StudioCommandBar: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(StudioColor.cyan.opacity(0.13))
                Image(systemName: store.section.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StudioColor.cyan)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.section.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                Text(store.section.subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(StudioColor.textFaint)
            }

            Spacer(minLength: 18)

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            StudioPill(
                title: "\(store.themes.count) worlds",
                tint: StudioColor.violet,
                symbol: "square.stack.3d.up"
            )

            HStack(spacing: 7) {
                StatusDot(color: store.connectionColor, isPulsing: store.runtime.connection == .connected)
                Text(store.runtime.connection.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(StudioColor.textMuted)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(StudioColor.line, lineWidth: 1)
            }

            StudioIconButton(symbol: "arrow.clockwise", help: "Refresh Codex status") {
                store.refreshRuntime()
            }
            StudioIconButton(symbol: "arrow.up.forward.app", help: "Open themed Codex", tint: StudioColor.cyan) {
                store.openCodex()
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(.thinMaterial)
    }
}
