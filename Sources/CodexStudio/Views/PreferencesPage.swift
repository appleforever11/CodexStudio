import SwiftUI

struct PreferencesPage: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    StudioSectionHeading(title: "Settings", detail: "Appearance, local storage, and a dependable connection.")
                    Spacer()
                    StudioActionButton(title: "Refresh status", symbol: "arrow.clockwise",
                        busy: store.isRefreshingRuntime) { store.refreshRuntime() }
                        .disabled(store.isRefreshingRuntime || store.isApplying)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 350), spacing: 18, alignment: .top)], spacing: 18) {
                    behaviorCard
                    runtimeCard
                    sourceCard
                    recoveryCard
                }
                diagnosticsCard
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("page.settings")
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
            SettingLine(label: "Studio operation", value: store.runtimePhase.label)
            SettingLine(label: "Relaunch recovery", value: store.runtime.persistenceEnabled ? "Armed" : "Not armed")
            if let lastVerifiedAt = store.runtime.lastVerifiedAt {
                SettingLine(label: "Last verification", value: lastVerifiedAt)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(radius: 18)
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            cardHeading("Local sources", symbol: "shippingbox.fill", tint: StudioColor.violet)
            SourceRow(title: "Managed Codex library", detail: "\(store.sourceSummary.localCount) themes", path: store.sourceSummary.managedPath)
            Text("Bundled Apple artwork and imported themes are kept in the managed library. No external image folders are scanned.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await store.bootstrap(force: true) }
            } label: {
                Label("Re-scan sources", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioColor.cyan)
            }
            .buttonStyle(StudioPressableButtonStyle())
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
            Text("If a theme ever looks wrong, stop the managed layer and return Codex to its original appearance. Relaunch recovery verifies the themed process with bounded retries, while your theme library remains untouched.")
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
            .buttonStyle(StudioPressableButtonStyle())
            .disabled(!store.canApply)

            Button {
                store.openRuntimeLog()
            } label: {
                Label("Open recovery log", systemImage: "doc.text.magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioColor.textMuted)
            }
            .buttonStyle(StudioPressableButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(radius: 18)
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            cardHeading("Diagnostics", symbol: "stethoscope", tint: StudioColor.cyan)
            Text("Copy a safe summary of the local catalog and runtime state when troubleshooting. It excludes prompts, artwork bytes, and credentials.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioColor.textMuted)
                .lineSpacing(2)

            VStack(alignment: .leading, spacing: 8) {
                SettingLine(label: "Catalog", value: store.isScanningLibrary ? "Refreshing" : "Ready")
                SettingLine(label: "Runtime", value: store.runtime.connection.label)
                SettingLine(label: "Operation", value: store.runtimePhase.label)
            }

            HStack(spacing: 12) {
                Button {
                    store.copyDiagnostics()
                } label: {
                    Label("Copy diagnostics", systemImage: "doc.on.doc")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(StudioColor.ink)
                        .padding(.horizontal, 13)
                        .frame(height: 36)
                        .background(StudioColor.spectrum, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(StudioPressableButtonStyle())
                .accessibilityIdentifier("settings.copy-diagnostics")

                Button {
                    store.openSupportFolder()
                } label: {
                    Label("Open support folder", systemImage: "folder")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudioColor.textMuted)
                        .padding(.horizontal, 13)
                        .frame(height: 36)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(StudioColor.line, lineWidth: 1)
                        }
                }
                .buttonStyle(StudioPressableButtonStyle())
                .accessibilityIdentifier("settings.open-support-folder")
            }
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
