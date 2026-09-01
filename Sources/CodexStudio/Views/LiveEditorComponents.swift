// Shared preview regions, rows, and palette values.

import SwiftUI

struct PreviewRegion<Content: View>: View {
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

struct PreviewRailItem: View {
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

struct PreviewSettingRow: View {
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
struct PreviewThemeValues {
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
