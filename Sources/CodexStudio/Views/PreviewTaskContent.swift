import SwiftUI

struct PreviewTaskContent: View {
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
