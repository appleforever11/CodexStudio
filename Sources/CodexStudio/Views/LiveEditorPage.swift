import SwiftUI

struct LiveEditorPage: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("LIVE EDITOR")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.7)
                        .foregroundStyle(StudioColor.cyan)
                    Text("Tune the system in context.")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioColor.text)
                    Text("Select a surface in the emulated Codex canvas. Every change stays local until you choose what to do with it.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(StudioColor.textMuted)
                }
                Spacer()
                if let theme = store.selectedTheme {
                    HStack(spacing: 9) {
                        ThemeSwatch(theme: theme, size: 28)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("EDITING")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(StudioColor.textFaint)
                            Text(theme.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(StudioColor.text)
                        }
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 19)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 17) {
                    previewColumn
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                    EditorInspector()
                        .frame(width: 270)
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
            .padding(.horizontal, 28)
            .padding(.bottom, 30)
        }
        .background(StudioColor.ink)
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
                    StatusDot(color: StudioColor.cyan, isPulsing: store.motionEnabled)
                    Text("Interactive canvas")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StudioColor.text)
                }
                Spacer()
                Picker("Preview", selection: $store.previewMode) {
                    ForEach(PreviewMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }
            if let theme = store.selectedTheme {
                CodexLivePreview(theme: theme)
            } else {
                ContentUnavailableView("Choose a theme", systemImage: "paintpalette")
                    .frame(maxWidth: .infinity, minHeight: 530)
            }
        }
    }
}

private struct CodexLivePreview: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme

    private var values: PreviewThemeValues {
        PreviewThemeValues(theme: theme, store: store)
    }

    var body: some View {
        ZStack {
            values.background
            if theme.imagePath != nil {
                ThemeArtworkView(theme: theme, animated: store.motionEnabled, showOverlay: false)
                    .opacity(0.24)
            } else {
                ThemeArtworkView(theme: theme, animated: store.motionEnabled, showOverlay: false)
                    .opacity(0.38)
            }
            LinearGradient(colors: [values.background.opacity(0.48), values.background.opacity(0.80)], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 0) {
                previewTitleBar
                GeometryReader { proxy in
                    let railWidth = min(126, max(88, proxy.size.width * 0.22))
                    HStack(spacing: 0) {
                        previewRail
                            .frame(width: railWidth)
                        Rectangle()
                            .fill(values.line)
                            .frame(width: 1)
                        previewMain
                            .frame(width: max(0, proxy.size.width - railWidth - 1), alignment: .topLeading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .frame(width: 126)
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

private struct PreviewHomeContent: View {
    @EnvironmentObject private var store: StudioStore
    let values: PreviewThemeValues

    var body: some View {
        VStack(spacing: 0) {
            previewHeader(title: "Workspace", subtitle: "Choose a project to get started")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PreviewRegion(surface: .homeHero, values: values) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GOOD EVENING, KEVIN")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(1.4)
                                .foregroundStyle(values.accent)
                            Text("What are we making today?")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(values.text)
                            Text("A calm surface for ambitious work.")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(values.muted)
                        }
                        .padding(19)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(values.panel.opacity(store.draftOpacity), in: RoundedRectangle(cornerRadius: store.draftRadius, style: .continuous))
                    }
                    HStack(spacing: 10) {
                        ForEach(["Understand code", "Build a feature"], id: \.self) { label in
                            PreviewRegion(surface: .suggestion, values: values) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: label.hasPrefix("Understand") ? "magnifyingglass" : "hammer")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(values.accent)
                                    Text(label)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(values.text)
                                    Text("Start with a focused prompt")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(values.muted)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(values.panel.opacity(store.draftOpacity), in: RoundedRectangle(cornerRadius: store.draftRadius * 0.72, style: .continuous))
                            }
                        }
                    }
                    Spacer(minLength: 80)
                }
                .padding(22)
            }
            PreviewComposer(values: values)
        }
    }

    private func previewHeader(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(values.text)
                Text(subtitle)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(values.muted)
            }
            Spacer()
            HStack(spacing: 7) {
                Text("main")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(values.text)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(values.muted)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(values.panelAlt.opacity(0.75), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }
}

private struct PreviewTaskContent: View {
    @EnvironmentObject private var store: StudioStore
    let values: PreviewThemeValues

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Codex Studio")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(values.text)
                    Text("Theme systems / live editor")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(values.muted)
                }
                Spacer()
                StudioPill(title: "working", tint: values.accent, symbol: "circle.fill")
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    PreviewRegion(surface: .userBubble, values: values) {
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(values.accentAlt).frame(width: 18, height: 18)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("You")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(values.accentAlt)
                                Text("Refine the editor so the theme feels native, not painted on.")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(values.text)
                                    .lineSpacing(2)
                            }
                        }
                        .padding(12)
                        .background(values.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: store.draftRadius * 0.72, style: .continuous))
                    }
                    PreviewRegion(surface: .assistantBubble, values: values) {
                        HStack(alignment: .top, spacing: 8) {
                            ZStack {
                                Circle().fill(values.accent.opacity(0.22))
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(values.accent)
                            }
                            .frame(width: 18, height: 18)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("Codex")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(values.accent)
                                Text("I’ll keep the canvas tactile: visible hierarchy, measured glow, and an inspector that stays out of the way.")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(values.text)
                                    .lineSpacing(2)
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Design direction understood")
                                }
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(values.accentAlt)
                            }
                        }
                        .padding(12)
                        .background(values.panel.opacity(store.draftOpacity), in: RoundedRectangle(cornerRadius: store.draftRadius * 0.72, style: .continuous))
                    }
                    PreviewRegion(surface: .toolCard, values: values) {
                        HStack(spacing: 9) {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(values.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Tool · Preview runtime")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(values.text)
                                Text("Loaded 14 surfaces in 0.18s")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(values.muted)
                            }
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.green)
                        }
                        .padding(11)
                        .background(values.secondary.opacity(0.34), in: RoundedRectangle(cornerRadius: store.draftRadius * 0.52, style: .continuous))
                    }
                    PreviewRegion(surface: .codeBlock, values: values) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ThemeTokens.swift")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(values.muted)
                            Text("let surface = palette.panel\nlet accent = palette.accent\nlet rhythm = .deliberate")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(values.accentAlt)
                                .lineSpacing(3)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(values.background.opacity(0.82), in: RoundedRectangle(cornerRadius: store.draftRadius * 0.52, style: .continuous))
                    }
                    Spacer(minLength: 52)
                }
                .padding(22)
            }
            PreviewComposer(values: values)
        }
    }
}

private struct PreviewSettingsContent: View {
    @EnvironmentObject private var store: StudioStore
    let values: PreviewThemeValues

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(values.text)
                    Text("Adjust the workspace around your habits.")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(values.muted)
                }
                Spacer()
            }
            .padding(.bottom, 6)

            PreviewRegion(surface: .settingsPanel, values: values) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("APPEARANCE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(values.accent)
                    PreviewSettingRow(title: "Theme", value: "System", values: values)
                    PreviewSettingRow(title: "Reduce motion", value: "Off", values: values)
                    PreviewSettingRow(title: "Composer density", value: "Comfortable", values: values)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(values.panel.opacity(store.draftOpacity), in: RoundedRectangle(cornerRadius: store.draftRadius, style: .continuous))
            }
            Spacer()
        }
        .padding(22)
    }
}

private struct PreviewComposer: View {
    @EnvironmentObject private var store: StudioStore
    let values: PreviewThemeValues

    var body: some View {
        PreviewRegion(surface: .composer, values: values) {
            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(values.muted)
                Text("Ask Codex anything…")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(values.muted)
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(values.muted)
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(values.accent)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(values.panelAlt.opacity(0.90), in: RoundedRectangle(cornerRadius: store.draftRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: store.draftRadius, style: .continuous).stroke(values.accent.opacity(0.28), lineWidth: 1))
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }
}

private struct PreviewRegion<Content: View>: View {
    @EnvironmentObject private var store: StudioStore
    let surface: PreviewSurface
    let values: PreviewThemeValues
    @ViewBuilder let content: Content

    var body: some View {
        content
            .overlay {
                if store.inspectorEnabled && store.selectedSurface == surface {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(values.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .shadow(color: values.accent.opacity(0.50), radius: 7)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard store.inspectorEnabled else { return }
                store.selectedSurface = surface
            }
            .accessibilityAddTraits(store.inspectorEnabled ? .isButton : [])
            .accessibilityLabel(store.inspectorEnabled ? "Edit \(surface.label)" : surface.label)
    }
}

private struct PreviewRailItem: View {
    let icon: String
    let title: String
    let values: PreviewThemeValues

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .frame(width: 13)
            Text(title)
                .font(.system(size: 8, weight: .medium))
            Spacer()
        }
        .foregroundStyle(values.muted)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

private struct PreviewSettingRow: View {
    let title: String
    let value: String
    let values: PreviewThemeValues

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(values.text)
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(values.muted)
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(values.muted)
        }
        .padding(.vertical, 3)
    }
}

@MainActor
private struct PreviewThemeValues {
    let background: Color
    let panel: Color
    let panelAlt: Color
    let accent: Color
    let accentAlt: Color
    let secondary: Color
    let text: Color
    let muted: Color
    let line: Color

    init(theme: Theme, store: StudioStore) {
        background = Color(hex: theme.palette.background)
        panel = Color(hex: theme.palette.panel)
        panelAlt = Color(hex: theme.palette.panelAlt)
        accent = store.draftAccent
        accentAlt = Color(hex: theme.palette.accentAlt)
        secondary = Color(hex: theme.palette.secondary)
        text = Color(hex: theme.palette.text)
        muted = Color(hex: theme.palette.muted)
        line = Color(hex: theme.palette.accent).opacity(0.28)
    }
}

private struct EditorInspector: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Inspector")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(StudioColor.text)
                        Text(store.selectedSurface.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(StudioColor.cyan)
                    }
                    Spacer()
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(StudioColor.textFaint)
                }

                Text(store.selectedSurface.tokenHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(StudioColor.line)

                Toggle(isOn: $store.inspectorEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Surface picking")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Click regions in the canvas")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(StudioColor.textFaint)
                    }
                }
                .toggleStyle(.switch)
                .tint(StudioColor.cyan)

                VStack(alignment: .leading, spacing: 8) {
                    inspectorLabel("Accent signal")
                    HStack {
                        ColorPicker("Accent", selection: $store.draftAccent, supportsOpacity: false)
                            .labelsHidden()
                        Text(store.draftAccent.hexDescription)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(StudioColor.textMuted)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                inspectorSlider(title: "Panel opacity", value: $store.draftOpacity, range: 0.45...1, valueLabel: "\(Int(store.draftOpacity * 100))%")
                inspectorSlider(title: "Backdrop softness", value: $store.draftBlur, range: 0...32, valueLabel: "\(Int(store.draftBlur)) px")
                inspectorSlider(title: "Corner radius", value: $store.draftRadius, range: 4...34, valueLabel: "\(Int(store.draftRadius)) px")

                Divider().overlay(StudioColor.line)

                VStack(alignment: .leading, spacing: 10) {
                    inspectorLabel("Source palette")
                    if let theme = store.selectedTheme {
                        PaletteRow(label: "Canvas", color: Color(hex: theme.palette.background), value: theme.palette.background)
                        PaletteRow(label: "Surface", color: Color(hex: theme.palette.panel), value: theme.palette.panel)
                        PaletteRow(label: "Accent", color: store.draftAccent, value: store.draftAccent.hexDescription)
                    }
                }

                VStack(spacing: 8) {
                    Button {
                        store.saveEditorDraft()
                    } label: {
                        Label("Save as local draft", systemImage: "square.and.arrow.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(StudioColor.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.applySelectedTheme()
                    } label: {
                        Label(store.isApplying ? "Applying…" : "Apply source theme", systemImage: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(StudioColor.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(StudioColor.cyan, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isApplying || store.selectedTheme?.isInstalled != true)
                    .opacity(store.selectedTheme?.isInstalled == true ? 1 : 0.45)
                }

                Text("Draft controls shape the emulated canvas. Applying a source theme is the only action that touches Codex, and it is verified after the runtime returns.")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(StudioColor.textFaint)
                    .lineSpacing(2)
            }
            .padding(17)
        }
        .scrollIndicators(.hidden)
        .studioPanel(radius: 18, fill: StudioColor.inkRaised.opacity(0.70))
    }

    private func inspectorLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(StudioColor.textFaint)
    }

    private func inspectorSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, valueLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(StudioColor.textFaint)
            }
            Slider(value: value, in: range)
                .tint(StudioColor.cyan)
        }
    }
}
