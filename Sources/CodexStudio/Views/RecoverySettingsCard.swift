import SwiftUI

struct RecoverySettingsCard: View {
    @EnvironmentObject private var store: StudioStore
    @State private var confirmRestore = false
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SettingsCardHeading("Recovery", symbol: "arrow.counterclockwise", tint: .orange)
            Text("If a theme ever looks wrong, stop the managed layer and return Codex to its original appearance. Relaunch recovery verifies the themed process with bounded retries, while your theme library remains untouched.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioColor.textMuted)
                .lineSpacing(2)
            Button {
                confirmRestore = true
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
        .confirmationDialog("Restore Codex’s original appearance?", isPresented: $confirmRestore) {
            Button("Restore original appearance", role: .destructive) { store.restoreOriginal() }
        } message: {
            Text("This stops the managed theme layer. Your local artwork and favorites are kept.")
        }
    }
}
