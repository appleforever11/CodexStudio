// Live editor controls and source-palette inspector.

import SwiftUI

struct EditorInspector: View {
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
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(StudioPressableButtonStyle())

                    Button {
                        store.applySelectedTheme()
                    } label: {
                        Label(store.isApplying ? "Applying…" : "Apply source theme", systemImage: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(StudioColor.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(StudioColor.spectrum, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(StudioPressableButtonStyle())
                    .disabled(store.isApplying || store.selectedTheme?.isInstalled != true)
                    .opacity(store.selectedTheme?.isInstalled == true ? 1 : 0.45)
                }

                Text("Draft controls shape the emulated canvas. Applying a source theme is the only action that touches Codex, and it is verified after the runtime returns.")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(StudioColor.textFaint)
                    .lineSpacing(2)
            }
            .padding(18)
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
