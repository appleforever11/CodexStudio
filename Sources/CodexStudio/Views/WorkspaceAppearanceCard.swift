import AppKit
import SwiftUI

struct WorkspaceAppearanceCard: View {
    @EnvironmentObject private var store: StudioStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCardHeading("ChatGPT workspace", symbol: "rectangle.3.group", tint: StudioColor.cyan)
            Text("Both sidebars share the same glass. Chat surfaces can be tuned independently. Changes stay here until you apply them.")
                .font(.callout).foregroundStyle(.secondary)
            Toggle("Enable workspace enhancements", isOn: $store.workspaceAppearance.enabled)
            GroupBox("Sidebar glass · left and right") {
                VStack {
                    slider("Opacity", value: $store.workspaceAppearance.sidebarOpacity, range: 0...1)
                    slider("Wallpaper dimming", value: $store.workspaceAppearance.sidebarDim, range: 0...0.8)
                    slider("Blur", value: $store.workspaceAppearance.sidebarBlur, range: 0...48, unit: "px")
                    slider("Row spacing", value: $store.workspaceAppearance.rowSpacing, range: 2...12, unit: "px")
                    Toggle("Wrap chat titles", isOn: $store.workspaceAppearance.wrapTitles)
                }.padding(8)
            }
            GroupBox("Conversation") {
                VStack {
                    slider("Opacity", value: $store.workspaceAppearance.chatOpacity, range: 0...1)
                    slider("Wallpaper dimming", value: $store.workspaceAppearance.chatDim, range: 0...0.8)
                    slider("Blur", value: $store.workspaceAppearance.chatBlur, range: 0...32, unit: "px")
                    Toggle("One surface per response", isOn: $store.workspaceAppearance.groupResponses)
                    Toggle("Keep my place while new content arrives", isOn: $store.workspaceAppearance.preserveReading)
                    Toggle("Show Return to latest", isOn: $store.workspaceAppearance.showLatest)
                    Toggle("Expand search context and highlight matches", isOn: $store.workspaceAppearance.searchContext)
                    slider("Reading width", value: $store.workspaceAppearance.readingWidth, range: 560...1120, unit: "px")
                    Toggle("Start in focused reading view", isOn: $store.workspaceAppearance.focusByDefault)
                }.padding(8)
            }
            HStack {
                Button("Apply workspace appearance") { store.applyWorkspaceAppearance() }
                    .buttonStyle(.borderedProminent)
                Button("Undo last change") { store.applyWorkspaceAppearance(undo: true) }
                Button("Defaults") { store.workspaceAppearance = .init() }
            }.disabled(!store.canApply)
            if !store.workspaceAppearanceMessage.isEmpty {
                Text(store.workspaceAppearanceMessage).font(.caption).textSelection(.enabled)
            }
            if let point = WorkspaceAppearanceService.pinnedRestorePoint {
                Button("Open stable runtime restore point") { NSWorkspace.shared.open(point) }
                Text("The saved runtime includes a verified restore command. Undo above affects appearance settings only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).studioPanel(radius: 18)
    }
    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String = "%") -> some View {
        HStack {
            Text(label).frame(width: 150, alignment: .leading)
            Slider(value: value, in: range)
            Text("\(Int((value.wrappedValue * (unit == "%" ? 100 : 1)).rounded()))\(unit)")
                .monospacedDigit().frame(width: 55, alignment: .trailing)
        }.font(.callout)
    }
}
