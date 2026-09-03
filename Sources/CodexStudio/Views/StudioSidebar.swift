import SwiftUI

struct StudioSidebar: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        VStack(spacing: 0) {
            // WindowGroup already reserves the native macOS titlebar. Keep
            // this brand row in the document area so it aligns with the
            // command bar instead of adding a second, artificial titlebar
            // gap below the traffic lights.
            brand
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(.thinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(StudioColor.line)
                        .frame(height: 1)
                }

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WORKSPACE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.1)
                            .foregroundStyle(StudioColor.textFaint)
                            .padding(.horizontal, 18)
                            .padding(.top, 5)
                            .padding(.bottom, 4)

                        ForEach(StudioSection.allCases) { section in
                            Button {
                                if section == .themes {
                                    store.selectThemes()
                                } else {
                                    store.selectSection(section)
                                }
                            } label: {
                                StudioNavigationRow(
                                    section: section,
                                    count: section == .themes ? store.themes.count : nil,
                                    isSelected: store.section == section
                                )
                            }
                            .buttonStyle(StudioPressableButtonStyle())
                            .padding(.horizontal, 9)
                            .accessibilityIdentifier("sidebar.\(section.rawValue)")
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("COLLECTION")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.1)
                            .foregroundStyle(StudioColor.textFaint)
                            .padding(.horizontal, 18)
                            .padding(.top, 10)
                            .padding(.bottom, 4)

                        Button {
                            store.selectFavorites()
                        } label: {
                            StudioNavigationRow(
                                title: "Favorites",
                                subtitle: "Saved themes",
                                systemImage: "star.fill",
                                count: store.favoriteCount,
                                isSelected: store.section == .themes && store.themeFilter == .favorites
                            )
                        }
                        .buttonStyle(StudioPressableButtonStyle())
                        .padding(.horizontal, 9)
                        .accessibilityIdentifier("sidebar.favorites")

                        Button {
                            store.selectRecent()
                        } label: {
                            StudioNavigationRow(
                                title: "Recently used",
                                subtitle: "Last opened",
                                systemImage: "clock.arrow.circlepath",
                                count: store.recentThemes.count,
                                isSelected: store.section == .themes && store.themeFilter == .recent
                            )
                        }
                        .buttonStyle(StudioPressableButtonStyle())
                        .padding(.horizontal, 9)
                        .accessibilityIdentifier("sidebar.recent")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            Spacer(minLength: 0)

            if let selectedTheme = store.selectedTheme {
                SidebarFocusCard(theme: selectedTheme)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
            }

            // Keep the connection controls intrinsic-height and flush with
            // the bottom edge; a fixed footer height left an unnecessary
            // blank band below the launch button on taller windows.
            Group {
                sidebarFooter
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
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
                    Text(store.runtimePhase.label)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(store.runtimePhase == .failed ? .orange : StudioColor.textFaint)
                }
                Spacer()
                Button {
                    store.refreshRuntime()
                } label: {
                    Group {
                        if store.isRefreshingRuntime {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .foregroundStyle(StudioColor.textMuted)
                    .frame(width: 26, height: 26)
                }
                .buttonStyle(StudioPressableButtonStyle())
                .disabled(store.isRefreshingRuntime)
                .help("Refresh Codex status")
                .accessibilityLabel("Refresh Codex status")
            }

            Button {
                store.openCodex()
            } label: {
                Label(
                    store.isOpeningCodex ? "Preparing Codex…" : "Open themed Codex",
                    systemImage: store.isOpeningCodex ? "hourglass" : "arrow.up.forward.app"
                )
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(StudioColor.cyan)
            .disabled(store.isOpeningCodex)
        }
    }
}

private struct StudioNavigationRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let count: Int?
    let isSelected: Bool
    let accessibilityTitle: String

    init(section: StudioSection, count: Int?, isSelected: Bool) {
        self.title = section.label
        self.subtitle = section.subtitle
        self.systemImage = section.systemImage
        self.count = count
        self.isSelected = isSelected
        self.accessibilityTitle = count.map { "\(section.label), \($0) themes" } ?? section.label
    }

    init(title: String, subtitle: String, systemImage: String, count: Int?, isSelected: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.count = count
        self.isSelected = isSelected
        switch title {
        case "Favorites":
            self.accessibilityTitle = count.map { "Favorites, \($0) saved themes" } ?? title
        case "Recently used":
            self.accessibilityTitle = count.map { "Recently used, \($0) recently selected themes" } ?? title
        default:
            self.accessibilityTitle = count.map { "\(title), \($0) themes" } ?? title
        }
    }

    var body: some View {
        Label {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(subtitle)
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
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                // Match the brand mark's 34-point slot so every title begins
                // on the same vertical guide while the smaller symbol stays
                // optically centered within it.
                .frame(width: 34)
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
        .accessibilityLabel(accessibilityTitle)
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

            ThemeArtworkView(theme: theme, animated: store.motionEnabled, showOverlay: false)
                .frame(maxWidth: .infinity)
                .frame(height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(store.runtime.activeThemeID == theme.id ? "Live in Codex" : "Preview selected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(store.runtime.activeThemeID == theme.id ? StudioColor.mint : StudioColor.textFaint)
            }
            .padding(.horizontal, 1)

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
