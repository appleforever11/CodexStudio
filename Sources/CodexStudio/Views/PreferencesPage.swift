import SwiftUI

struct PreferencesPage: View {
    @EnvironmentObject private var store: StudioStore
    @State private var selection = SettingsArea.general

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    StudioSectionHeading(title: "Studio settings", detail: "Your space. Your preferences. Everything on this Mac.")
                    Spacer()
                    StudioActionButton(title: "Refresh status", symbol: "arrow.clockwise",
                        busy: store.isRefreshingRuntime) { store.refreshRuntime() }
                        .disabled(store.isRefreshingRuntime || store.isApplying)
                }
                Picker("Settings area", selection: $selection) {
                    ForEach(SettingsArea.allCases) { area in Text(area.rawValue).tag(area) }
                }.pickerStyle(.segmented).frame(maxWidth: 500)
                VStack(alignment: .leading, spacing: 18) {
                    switch selection {
                    case .general: AppearanceSettingsCard()
                    case .connection: RuntimeSettingsCard()
                    case .library: LibrarySettingsCard()
                    case .recovery: RecoverySettingsCard()
                    }
                    if selection == .connection || selection == .recovery {
                        DiagnosticsSettingsCard()
                    }
                }.frame(maxWidth: 760, alignment: .leading)
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("page.settings")
    }
}

private enum SettingsArea: String, CaseIterable, Identifiable {
    case general = "General", connection = "Connection", library = "Library", recovery = "Recovery"
    var id: String { rawValue }
}

struct PreferencesView: View {
    var body: some View {
        PreferencesPage().frame(minWidth: 640, minHeight: 500)
    }
}
