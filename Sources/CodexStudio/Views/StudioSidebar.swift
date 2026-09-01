import SwiftUI

struct StudioSidebar: View {
    @EnvironmentObject private var store: StudioStore
    private let brandHeaderHeight: CGFloat = 54
    // macOS 26 can report a split-view column a little taller than its
    // visible client area. Keep a deliberate lower buffer so the connection
    // row and launch button remain fully visible instead of being clipped by
    // the window edge.
    private let sidebarFooterHeight: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // WindowGroup already reserves the native macOS titlebar. Keep
                // this brand row in the document area so it aligns with the
                // command bar instead of adding a second, artificial titlebar
                // gap below the traffic lights.
                brand
                    .padding(.horizontal, 18)
                    .frame(height: brandHeaderHeight)
                    .background(.thinMaterial)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(StudioColor.line)
                            .frame(height: 1)
                    }

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Workspace")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(StudioColor.textFaint)
                                .padding(.horizontal, 18)
                                .padding(.bottom, 4)

                            ForEach(StudioSection.allCases) { section in
                                Button {
                                    store.selectSection(section)
                                } label: {
                                    StudioNavigationRow(
                                        section: section,
                                        count: section == .themes ? store.themes.count : nil,
                                        isSelected: store.section == section
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 9)
                            }
                        }

                        if let selectedTheme = store.selectedTheme {
                            SidebarFocusCard(theme: selectedTheme)
                                .padding(.horizontal, 12)
                                .padding(.top, 14)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                .frame(
                    width: proxy.size.width,
                    height: max(0, proxy.size.height - brandHeaderHeight - sidebarFooterHeight),
                    alignment: .topLeading
                )

                sidebarFooter
                    .padding(.horizontal, 14)
                    .padding(.top, 11)
                    .padding(.bottom, 14)
                    .frame(width: proxy.size.width, height: sidebarFooterHeight, alignment: .topLeading)
                    .background(.regularMaterial)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(StudioColor.line)
                            .frame(height: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(StudioColor.line)
                .frame(width: 1)
        }
    }

    private var brand: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(StudioColor.spectrum)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(StudioColor.ink)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Studio")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                Text("Visual systems for Codex")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(StudioColor.textFaint)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                StatusDot(color: store.connectionColor, isPulsing: store.runtime.connection == .connected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.runtime.connection.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudioColor.text)
                    Text(store.runtime.codexVersion.map { "Codex \($0)" } ?? "Local preview")
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
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Refresh Codex status")
            }

            Button {
                store.openCodex()
            } label: {
                Label("Open themed Codex", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(StudioColor.cyan)
        }
    }
}

private struct StudioNavigationRow: View {
    let section: StudioSection
    let count: Int?
    let isSelected: Bool

    var body: some View {
        Label {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.label)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(section.subtitle)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let count {
                    Text(count.formatted(.number.notation(.compactName)))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? StudioColor.cyan : StudioColor.textFaint)
                }
            }
        } icon: {
            Image(systemName: section.systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 18)
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(isSelected ? StudioColor.text : StudioColor.textMuted)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isSelected ? StudioColor.inkSoft.opacity(0.84) : Color.clear,
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(StudioColor.cyan)
                    .frame(width: 3, height: 22)
                    .padding(.leading, 2)
            }
        }
        .accessibilityLabel(count.map { "\(section.label), \($0) themes" } ?? section.label)
    }
}

private struct SidebarFocusCard: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Now playing")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(StudioColor.textFaint)
                Spacer()
                StatusDot(color: store.connectionColor, isPulsing: store.runtime.connection == .connected)
            }

            ZStack(alignment: .bottomLeading) {
                ThemeArtworkView(theme: theme, animated: store.motionEnabled, showOverlay: false)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(store.runtime.activeThemeID == theme.id ? "Live in Codex" : "Preview selected")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(store.runtime.activeThemeID == theme.id ? StudioColor.mint : .white.opacity(0.72))
                }
                .padding(9)
            }
            .frame(height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            Button {
                store.applySelectedTheme()
            } label: {
                Label(store.isApplying ? "Applying…" : "Apply selection", systemImage: "bolt.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(StudioColor.cyan)
            .disabled(store.isApplying || !theme.isInstalled)
        }
        .padding(11)
        .studioPanel(radius: 15, fill: Color.white.opacity(0.045))
    }
}
