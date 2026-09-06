import SwiftUI

struct RuntimeSettingsCard: View {
    @EnvironmentObject private var store: StudioStore
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SettingsCardHeading("Codex runtime", symbol: "bolt.fill", tint: store.connectionColor)
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
            SettingsLine(label: "Active theme", value: store.runtime.activeThemeName ?? "None")
            SettingsLine(label: "Codex version", value: store.runtime.codexVersion ?? "Not reported")
            SettingsLine(label: "Loopback port", value: store.runtime.port.map(String.init) ?? "—")
            SettingsLine(label: "Studio operation", value: store.runtimePhase.label)
            SettingsLine(label: "Relaunch recovery", value: store.runtime.persistenceEnabled ? "Armed" : "Not armed")
            if let lastVerifiedAt = store.runtime.lastVerifiedAt {
                SettingsLine(label: "Last verification", value: lastVerifiedAt)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(radius: 18)
    }
}
