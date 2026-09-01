import SwiftUI

struct LiveEditorPage: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 20) {
                ThemeAtlasHeader(
                    eyebrow: "LIVE THEME LAB",
                    title: "Design against a living Codex.",
                    detail: "Select any surface inside the emulator, tune it in context, and keep every experiment local until you deliberately apply it.",
                    symbol: "slider.horizontal.below.square.filled.and.square"
                )
                Spacer()
                if let theme = store.selectedTheme {
                    VStack(alignment: .trailing, spacing: 8) {
                        StudioPill(title: "Editing live", tint: StudioColor.mint, symbol: "waveform.path.ecg")
                        HStack(spacing: 9) {
                            ThemeSwatch(theme: theme, size: 30)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(theme.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(StudioColor.text)
                                    .lineLimit(1)
                                Text(theme.collection)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(StudioColor.textFaint)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 17) {
                    previewColumn
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                    EditorInspector()
                        .frame(width: 296)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        previewColumn
                        EditorInspector()
                            .frame(maxWidth: .infinity)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [StudioColor.cyan.opacity(0.025), .clear, StudioColor.violet.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onChange(of: store.previewMode) { _, mode in
            store.selectedSurface = switch mode {
            case .home: .composer
            case .task: .assistantBubble
            case .settings: .settingsPanel
            }
        }
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                HStack(spacing: 7) {
                    ZStack {
                        Circle().fill(StudioColor.cyan.opacity(0.13))
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(StudioColor.cyan)
                    }
                    .frame(width: 29, height: 29)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Interactive Codex emulator")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Click a surface to inspect its tokens")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(StudioColor.textFaint)
                    }
                        .foregroundStyle(StudioColor.text)
                }
                Spacer()
                Picker(selection: $store.previewMode) {
                    ForEach(PreviewMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Preview mode")
                .frame(width: 220)
            }
            .padding(.horizontal, 12)
            .frame(height: 49)
            .studioPanel(radius: 14, fill: Color.white.opacity(0.035))
            if let theme = store.selectedTheme {
                CodexLivePreview(theme: theme)
            } else {
                ContentUnavailableView("Choose a theme", systemImage: "paintpalette")
                    .frame(maxWidth: .infinity, minHeight: 530)
            }
        }
    }
}
