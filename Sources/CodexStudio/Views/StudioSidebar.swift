import SwiftUI

struct StudioSidebar: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 5) {
                Text("WORKSPACE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(StudioColor.textFaint)
                    .padding(.horizontal, 13)
                    .padding(.bottom, 5)

                ForEach(StudioSection.allCases) { section in
                    SidebarRow(section: section, isSelected: store.section == section) {
                        store.selectSection(section)
                    }
                }
            }
            .padding(.horizontal, 10)

            if let selectedTheme = store.selectedTheme {
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("NOW PLAYING")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(StudioColor.textFaint)
                        Spacer()
                        StatusDot(color: store.connectionColor, isPulsing: store.runtime.connection == .connected)
                    }

                    HStack(spacing: 10) {
                        ThemeArtworkView(theme: selectedTheme, animated: store.motionEnabled)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedTheme.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(StudioColor.text)
                                .lineLimit(1)
                            Text(store.runtime.activeThemeID == selectedTheme.id ? "Applied to Codex" : "Preview selected")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(store.runtime.activeThemeID == selectedTheme.id ? .green : StudioColor.textMuted)
                                .lineLimit(1)
                        }
                    }

                    Button {
                        store.applySelectedTheme()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: store.isApplying ? "arrow.triangle.2.circlepath" : "bolt.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(store.isApplying ? "Applying…" : "Apply selection")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(StudioColor.ink)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .background(StudioColor.cyan, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isApplying || !selectedTheme.isInstalled)
                    .opacity(selectedTheme.isInstalled ? 1 : 0.48)
                }
                .padding(14)
                .studioPanel(radius: 16, fill: Color.white.opacity(0.055))
                .padding(.horizontal, 14)
                .padding(.top, 30)
            }

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 12) {
                RuntimeStatusLine()
                Button {
                    store.openCodex()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Open Codex")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("⌘O")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(StudioColor.textFaint)
                    }
                    .foregroundStyle(StudioColor.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .frame(width: 236)
        .background {
            LinearGradient(
                colors: [Color(hex: "#0B111B"), Color(hex: "#0A0E16"), Color(hex: "#10101B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(StudioColor.violet.opacity(0.12))
                    .frame(width: 190, height: 190)
                    .blur(radius: 42)
                    .offset(x: 70, y: -65)
            }
        }
    }

    private var brand: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [StudioColor.cyan, StudioColor.violet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "rectangle.3.group.bubble.left.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(StudioColor.ink)
            }
            .frame(width: 33, height: 33)
            .shadow(color: StudioColor.cyan.opacity(0.22), radius: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text("CODEX STUDIO")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(StudioColor.text)
                Text("art-direct your workspace")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(StudioColor.textMuted)
            }
        }
    }
}

private struct SidebarRow: View {
    let section: StudioSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.label)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    Text(section.subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isSelected ? StudioColor.textMuted : StudioColor.textFaint)
                }
                Spacer()
                if section == .themes {
                    Text("\(ThemeCatalog.curated.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? StudioColor.cyan : StudioColor.textFaint)
                }
            }
            .foregroundStyle(isSelected ? StudioColor.text : StudioColor.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(StudioColor.cyan.opacity(0.12))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(StudioColor.cyan)
                                .frame(width: 3)
                                .padding(.vertical, 7)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RuntimeStatusLine: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        HStack(spacing: 9) {
            StatusDot(color: store.connectionColor, isPulsing: store.runtime.connection == .connected)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.runtime.connection.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                Text(store.runtime.codexVersion.map { "Codex \($0)" } ?? "Local preview mode")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(StudioColor.textFaint)
            }
            Spacer()
            Button {
                store.refreshRuntime()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioColor.textMuted)
            }
            .buttonStyle(.plain)
            .help("Refresh Codex runtime status")
        }
        .padding(.horizontal, 3)
    }
}
