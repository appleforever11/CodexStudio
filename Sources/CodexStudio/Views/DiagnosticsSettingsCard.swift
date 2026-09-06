import SwiftUI

struct DiagnosticsSettingsCard: View {
    @EnvironmentObject private var store: StudioStore
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SettingsCardHeading("Diagnostics", symbol: "stethoscope", tint: StudioColor.cyan)
            Text("Copy a safe summary of the local catalog and runtime state when troubleshooting. It excludes prompts, artwork bytes, and credentials.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioColor.textMuted)
                .lineSpacing(2)

            VStack(alignment: .leading, spacing: 8) {
                SettingsLine(label: "Catalog", value: store.isScanningLibrary ? "Refreshing" : "Ready")
                SettingsLine(label: "Runtime", value: store.runtime.connection.label)
                SettingsLine(label: "Operation", value: store.runtimePhase.label)
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
}
