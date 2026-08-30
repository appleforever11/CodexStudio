import SwiftUI

struct PreferencesPage: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("SETTINGS")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.7)
                            .foregroundStyle(StudioColor.cyan)
                        Text("Keep the studio quiet and dependable.")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundStyle(StudioColor.text)
                        Text("Runtime details, local sources, and recovery controls live here—not in the way of the work.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(StudioColor.textMuted)
                    }
                    Spacer()
                    Button {
                        store.refreshRuntime()
                    } label: {
                        Label("Refresh status", systemImage: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(StudioColor.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .top, spacing: 15) {
                    runtimeCard
                    sourceCard
                }

                HStack(alignment: .top, spacing: 15) {
                    behaviorCard
                    recoveryCard
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 38)
        }
        .scrollIndicators(.hidden)
        .background(StudioColor.ink)
    }

    private var runtimeCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            cardHeading("Codex runtime", symbol: "bolt.fill", tint: store.connectionColor)
            HStack(spacing: 12) {
                StatusDot(color: store.connectionColor, isPulsing: store.runtime.connection == .connected)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.runtime.connection.label)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioColor.text)
                    Text(store.runtime.message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(StudioColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider().overlay(StudioColor.line)
            SettingLine(label: "Active theme", value: store.runtime.activeThemeName ?? "None")
            SettingLine(label: "Codex version", value: store.runtime.codexVersion ?? "Not reported")
            SettingLine(label: "Loopback port", value: store.runtime.port.map(String.init) ?? "—")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(radius: 18)
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            cardHeading("Local sources", symbol: "shippingbox.fill", tint: StudioColor.violet)
            SourceRow(title: "Managed Codex library", detail: "\(store.sourceSummary.localCount) themes", path: store.sourceSummary.managedPath)
            SourceRow(title: "WallBuddy bundle", detail: store.sourceSummary.wallBuddyCount > 0 ? "\(store.sourceSummary.wallBuddyCount) image assets" : "No wallpaper catalog in bundle", path: store.sourceSummary.wallBuddyPath)
            Button {
                Task { await store.bootstrap(force: true) }
            } label: {
                Label("Re-scan sources", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioColor.cyan)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(radius: 18)
    }

    private var behaviorCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            cardHeading("Studio behavior", symbol: "wand.and.stars", tint: StudioColor.cyan)
            Toggle(isOn: Binding(get: { store.motionEnabled }, set: store.setMotionEnabled)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Atmospheric motion")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StudioColor.text)
                    Text("Allow slow artwork movement in the canvas and cards.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(StudioColor.textMuted)
                }
            }
            .toggleStyle(.switch)
            .tint(StudioColor.cyan)
            Divider().overlay(StudioColor.line)
            Text("Codex Studio keeps the visual preview separate from the runtime apply path. A draft never silently changes Codex.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioColor.textMuted)
                .lineSpacing(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(radius: 18)
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            cardHeading("Recovery", symbol: "arrow.counterclockwise", tint: .orange)
            Text("If a theme ever looks wrong, stop the managed layer and return Codex to its original appearance. Your theme library remains untouched.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioColor.textMuted)
                .lineSpacing(2)
            Button {
                store.restoreOriginal()
            } label: {
                Label("Restore original appearance", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(store.isApplying)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(radius: 18)
    }

    private func cardHeading(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(StudioColor.text)
        }
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        PreferencesPage()
            .environmentObject(store)
            .frame(minWidth: 640, minHeight: 500)
    }
}

private struct SettingLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(StudioColor.textFaint)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(StudioColor.textMuted)
                .lineLimit(1)
        }
    }
}

private struct SourceRow: View {
    let title: String
    let detail: String
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                Spacer()
                Text(detail)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(StudioColor.cyan)
            }
            Text(path)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(StudioColor.textFaint)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
}
