import SwiftUI

struct AppearanceSettingsCard: View {
    @EnvironmentObject private var store: StudioStore
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SettingsCardHeading("Studio behavior", symbol: "wand.and.stars", tint: StudioColor.cyan)
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
}
