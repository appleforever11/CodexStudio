import AppKit
import SwiftUI

struct ThemeArtworkView: View {
    let theme: Theme
    var animated = false
    var showOverlay = true

    @State private var localImage: NSImage?
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shouldAnimate = animated && !reduceMotion
        ZStack {
            if let localImage {
                Image(nsImage: localImage)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(shouldAnimate && hasAppeared ? 1.035 : 1.0)
                    .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: hasAppeared)
            } else {
                ThemeGradientArtwork(theme: theme, animated: shouldAnimate, hasAppeared: hasAppeared)
            }

            if showOverlay {
                LinearGradient(
                    colors: [
                        Color(hex: theme.palette.background).opacity(0.10),
                        Color(hex: theme.palette.background).opacity(0.16),
                        Color.black.opacity(0.66)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .onAppear {
            if let path = theme.previewPath ?? theme.imagePath {
                localImage = NSImage(contentsOfFile: path)
            }
            guard shouldAnimate else { return }
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                hasAppeared = true
            }
        }
        .onChange(of: theme.previewPath) { _, _ in
            guard let path = theme.previewPath ?? theme.imagePath else {
                localImage = nil
                return
            }
            localImage = NSImage(contentsOfFile: path)
        }
    }
}

private struct ThemeGradientArtwork: View {
    let theme: Theme
    let animated: Bool
    let hasAppeared: Bool

    var body: some View {
        GeometryReader { proxy in
            let accent = Color(hex: theme.palette.accent)
            let accentAlt = Color(hex: theme.palette.accentAlt)
            let background = Color(hex: theme.palette.background)

            ZStack {
                LinearGradient(
                    colors: [background, Color(hex: theme.palette.panel), Color(hex: theme.palette.panelAlt)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(accent.opacity(0.72))
                    .frame(width: proxy.size.width * 0.82)
                    .blur(radius: proxy.size.width * 0.11)
                    .offset(x: proxy.size.width * (animated && hasAppeared ? 0.22 : 0.10), y: -proxy.size.height * 0.26)
                Circle()
                    .fill(accentAlt.opacity(0.38))
                    .frame(width: proxy.size.width * 0.68)
                    .blur(radius: proxy.size.width * 0.14)
                    .offset(x: -proxy.size.width * 0.28, y: proxy.size.height * 0.32)
                RoundedRectangle(cornerRadius: proxy.size.width * 0.08, style: .continuous)
                    .stroke(accent.opacity(0.46), lineWidth: 1)
                    .padding(proxy.size.width * 0.08)
                    .rotationEffect(.degrees(-8))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.72))
                    path.addCurve(
                        to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.56),
                        control1: CGPoint(x: proxy.size.width * 0.30, y: proxy.size.height * 0.36),
                        control2: CGPoint(x: proxy.size.width * 0.68, y: proxy.size.height * 0.80)
                    )
                }
                .stroke(accentAlt.opacity(0.58), style: StrokeStyle(lineWidth: 2, dash: [3, 9]))
            }
        }
    }
}

struct ThemeSwatch: View {
    let theme: Theme
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color(hex: theme.palette.accent))
            Rectangle().fill(Color(hex: theme.palette.accentAlt))
            Rectangle().fill(Color(hex: theme.palette.secondary))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).stroke(Color.white.opacity(0.28), lineWidth: 1))
    }
}
