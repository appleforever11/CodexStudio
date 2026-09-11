import SwiftUI

struct CodexCapabilitiesSettingsCard: View {
    @EnvironmentObject private var store: StudioStore

    private var snapshot: CodexCapabilitySnapshot { store.capabilities }

    private var healthColor: Color {
        switch snapshot.health {
        case .ready: StudioColor.mint
        case .partial: StudioColor.amber
        case .needsAttention: .orange
        case .unavailable: StudioColor.textFaint
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                SettingsCardHeading("Codex capabilities", symbol: snapshot.health.symbol, tint: healthColor)
                Spacer(minLength: 12)
                Button {
                    store.refreshCapabilities()
                } label: {
                    Label("Inspect again", systemImage: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isInspectingCapabilities)
                .accessibilityIdentifier("settings.inspect-capabilities")
            }

            HStack(alignment: .top, spacing: 10) {
                StatusDot(color: healthColor, isPulsing: snapshot.health == .ready)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.health.label)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioColor.text)
                    Text(snapshot.message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(StudioColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().overlay(StudioColor.line)

            VStack(alignment: .leading, spacing: 9) {
                SettingsLine(label: "Codex app", value: appValue)
                SettingsLine(label: "App-server", value: snapshot.appServerAvailable ? "Available · read-only inspection" : "Not detected")
                SettingsLine(label: "Renderer", value: rendererValue)
                SettingsLine(label: "Loopback port", value: snapshot.port.map(String.init) ?? "—")
                SettingsLine(label: "Bundled Node", value: snapshot.bundledNodeVersion ?? "Not reported")
                SettingsLine(label: "Codex CLI", value: snapshot.codexCLI ?? "Not reported")
                SettingsLine(label: "Runtime package", value: runtimeValue)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Declared capability surface")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudioColor.text)
                    Spacer()
                    Text(featureCountValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(StudioColor.textFaint)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(snapshot.highlightedFeatures) { feature in
                        CodexFeatureRow(feature: feature)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if let bundlePath = snapshot.bundlePath {
                    SettingsSourceRow(
                        title: "Detected app bundle",
                        detail: snapshot.bundleIdentifier ?? "Codex",
                        path: bundlePath
                    )
                }
                Text(checkedValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(StudioColor.textFaint)
                Text("This check reads local metadata and loopback target headers only. It does not connect to app-server or inspect account content.")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(StudioColor.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(radius: 18)
        .accessibilityIdentifier("settings.codex-capabilities")
    }

    private var appValue: String {
        let version = snapshot.appVersion ?? "Not found"
        guard let build = snapshot.appBuild else { return version }
        return "\(version) (\(build))"
    }

    private var rendererValue: String {
        let browser = snapshot.browserVersion ?? "Inspector unavailable"
        let protocolVersion = snapshot.cdpProtocol.map { " · CDP \($0)" } ?? ""
        return "\(browser)\(protocolVersion)"
    }

    private var runtimeValue: String {
        let installed = snapshot.installedRuntimeVersion ?? "not installed"
        guard let bundled = snapshot.bundledRuntimeVersion, bundled != installed else {
            return installed
        }
        return "Bundled \(bundled) · installed \(installed)"
    }

    private var featureCountValue: String {
        guard snapshot.featureCount > 0 else { return "Not reported" }
        return "\(snapshot.enabledFeatureCount) of \(snapshot.featureCount) enabled"
    }

    private var checkedValue: String {
        guard let checkedAt = snapshot.checkedAt else { return "Not checked yet" }
        return "Checked \(checkedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct CodexFeatureRow: View {
    let feature: CodexCapabilityFeature

    private var tint: Color { feature.enabled ? StudioColor.mint : StudioColor.textFaint }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: feature.enabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                    .lineLimit(1)
                Text(feature.availabilityLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 42, alignment: .leading)
        .background(StudioColor.ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(feature.label)
        .accessibilityValue(feature.availabilityLabel)
    }
}
