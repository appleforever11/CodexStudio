import SwiftUI

struct LiveEditorPage: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center) {
                        StudioSectionHeading(title: "Live editor", detail: store.selectedTheme?.name ?? "Choose a theme to start")
                        Spacer()
                        StudioActionButton(title: "Change theme", symbol: "square.grid.2x2") { store.selectThemes() }
                    }
                    if geometry.size.width >= 1000 {
                        HStack(alignment: .top, spacing: 20) {
                            previewColumn
                                .frame(maxWidth: .infinity)
                            EditorInspector().frame(width: 292, height: 650)
                        }
                    } else {
                        previewColumn
                        EditorInspector().frame(height: 560)
                    }
                }.padding(28)
            }.scrollIndicators(.hidden)
        }
        .onChange(of: store.previewMode) { _, mode in
            store.selectedSurface = switch mode {
            case .home: .composer
            case .task: .assistantBubble
            case .settings: .settingsPanel
            }
        }
        .accessibilityIdentifier("page.editor")
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Label("Codex preview", systemImage: "macwindow").font(.system(size: 12, weight: .semibold))
                Spacer()
                Picker("Preview mode", selection: $store.previewMode) {
                    ForEach(PreviewMode.allCases) { mode in Text(mode.label).tag(mode) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 220)
            }.padding(12).studioGlass(radius: 16)
            if let theme = store.selectedTheme {
                CodexLivePreview(theme: theme)
                    .frame(height: 580)
                    .background { ThemeAmbientGlow(theme: theme).opacity(0.45) }
            } else {
                ThemeAtlasEmptyState(title: "Choose a theme", detail: "Open Explore to find artwork for your workspace.")
                    .frame(height: 400)
            }
            Label("Preview only · Changes stay local until you save a draft or apply a theme.", systemImage: "lock")
                .font(.system(size: 10)).foregroundStyle(StudioColor.textMuted)
        }
    }
}
