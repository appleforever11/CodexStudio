import SwiftUI

struct PreviewSettingsContent: View {
    @EnvironmentObject private var store: StudioStore
    let values: PreviewThemeValues

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(values.text)
                    Text("Adjust the workspace around your habits.")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(values.muted)
                }
                Spacer()
            }
            .padding(.bottom, 6)

            PreviewRegion(surface: .settingsPanel, values: values) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("APPEARANCE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(values.accent)
                    PreviewSettingRow(title: "Theme", value: "System", values: values)
                    PreviewSettingRow(title: "Reduce motion", value: "Off", values: values)
                    PreviewSettingRow(title: "Composer density", value: "Comfortable", values: values)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(values.panel.opacity(store.draftOpacity), in: RoundedRectangle(cornerRadius: store.draftRadius, style: .continuous))
            }
            Spacer()
        }
        .padding(22)
    }
}
