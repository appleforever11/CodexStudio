import SwiftUI

struct PreviewHomeContent: View {
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
