// Interactive Codex canvas and mode-specific preview content.

import SwiftUI

struct CodexLivePreview: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme

    private var values: PreviewThemeValues {
        PreviewThemeValues(theme: theme, store: store)
    }

    var body: some View {
        GeometryReader { viewport in
        ZStack {
            values.background
                .overlay {
                ThemeArtworkView(theme: theme, animated: store.motionEnabled, showOverlay: false)
                    .frame(width: viewport.size.width, height: viewport.size.height)
                    .clipped()
                    .opacity(theme.imagePath != nil ? 0.24 : 0.38)
                }
            LinearGradient(colors: [values.background.opacity(0.48), values.background.opacity(0.80)], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 0) {
                previewTitleBar
                GeometryReader { proxy in
                    let railWidth = min(126, max(88, proxy.size.width * 0.22))
                    HStack(spacing: 0) {
                        previewRail
                            .frame(width: railWidth, height: proxy.size.height)
                        Rectangle()
                            .fill(values.line)
                            .frame(width: 1)
                        previewMain
                            .frame(width: max(0, proxy.size.width - railWidth - 1), height: proxy.size.height, alignment: .topLeading)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .topLeading)
        }
        .frame(minWidth: 0, idealWidth: 600, maxWidth: .infinity, minHeight: 530, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(values.line.opacity(0.9), lineWidth: 1))
        .shadow(color: values.accent.opacity(0.09), radius: 30, y: 12)
    }

    private var previewTitleBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Circle().fill(Color.red.opacity(0.7)).frame(width: 7, height: 7)
                Circle().fill(Color.orange.opacity(0.7)).frame(width: 7, height: 7)
                Circle().fill(Color.green.opacity(0.7)).frame(width: 7, height: 7)
            }
            Text("Codex")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(values.muted)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(values.accent)
                Text("LIVE PREVIEW")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(values.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(values.panel.opacity(0.86))
    }

    private var previewRail: some View {
        VStack(alignment: .leading, spacing: 9) {
            PreviewRegion(surface: .sidebar, values: values) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(LinearGradient(colors: [values.accent, values.accentAlt], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 22, height: 22)
                        Text("CODEX")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(values.text)
                    }
                    PreviewRegion(surface: .sidebarActive, values: values) {
                        HStack(spacing: 7) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("New task")
                                .font(.system(size: 10, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(values.text)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(values.accent.opacity(0.17), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        PreviewRailItem(icon: "arrow.triangle.branch", title: "Pull requests", values: values)
                        PreviewRailItem(icon: "calendar", title: "Scheduled", values: values)
                        PreviewRailItem(icon: "puzzlepiece.extension", title: "Plugins", values: values)
                        PreviewRailItem(icon: "safari", title: "Explore", values: values)
                    }
                    Spacer()
                    HStack(spacing: 7) {
                        Circle().fill(values.accentAlt).frame(width: 20, height: 20)
                        Text("Kevin")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(values.muted)
                        Spacer()
                        Image(systemName: "gearshape")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(values.muted)
                    }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(values.panel.opacity(0.62))
    }

    @ViewBuilder
    private var previewMain: some View {
        Group {
            switch store.previewMode {
            case .home:
                PreviewHomeContent(values: values)
            case .task:
                PreviewTaskContent(values: values)
            case .settings:
                PreviewSettingsContent(values: values)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
