import SwiftUI

struct LibrarySettingsCard: View {
    @EnvironmentObject private var store: StudioStore
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SettingsCardHeading("Local sources", symbol: "shippingbox.fill", tint: StudioColor.violet)
            SettingsSourceRow(title: "Managed Codex library", detail: "\(store.sourceSummary.localCount) themes", path: store.sourceSummary.managedPath)
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
}
