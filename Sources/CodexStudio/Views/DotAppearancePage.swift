import SwiftUI

struct DotAppearancePage: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StudioSectionHeading(title: "Your dot", detail: "A calmer conversation, with a clear voice for each of you.")
                preview
                VStack(alignment: .leading, spacing: 18) {
                    Toggle("Customize Dot conversations", isOn: $store.workspaceAppearance.dotEnabled)
                    ColorPicker("Dot bubbles", selection: color($store.workspaceAppearance.dotBubbleColor), supportsOpacity: false)
                    ColorPicker("My bubbles", selection: color($store.workspaceAppearance.dotUserBubbleColor), supportsOpacity: false)
                    adjustment("Wallpaper dimming", value: $store.workspaceAppearance.dotBackdropDim, range: 0...0.8, step: 0.01, percent: true)
                    adjustment("Glass softness", value: $store.workspaceAppearance.dotGlassBlur, range: 0...32)
                    adjustment("Message spacing", value: $store.workspaceAppearance.dotSpacing, range: 6...32)
                    adjustment("Rounded corners", value: $store.workspaceAppearance.dotRadius, range: 4...28)
                    Text("Dot messages sit on the left; yours sit on the right. Text color adapts to your bubble colors. Changes are saved when you apply.")
                        .font(.callout).foregroundStyle(.secondary)
                    if !store.workspaceAppearance.enabled {
                        Text("Enable workspace enhancements in Settings to apply Dot styling.")
                            .font(.callout).foregroundStyle(.orange)
                    }
                    HStack {
                        Button("Apply Dot appearance") { store.applyWorkspaceAppearance() }
                            .buttonStyle(.borderedProminent)
                        Button("Undo last appearance change") { store.applyWorkspaceAppearance(undo: true) }
                        Button("Blue & grey") {
                            store.workspaceAppearance.dotEnabled = true
                            store.workspaceAppearance.dotBubbleColor = "#2563EB"
                            store.workspaceAppearance.dotUserBubbleColor = "#4B5563"
                            store.workspaceAppearance.dotSpacing = 14
                            store.workspaceAppearance.dotRadius = 18
                            store.workspaceAppearance.dotBackdropDim = 0.32
                            store.workspaceAppearance.dotGlassBlur = 18
                        }
                    }.disabled(!store.canApply || !store.workspaceAppearance.enabled)
                    if !store.workspaceAppearanceMessage.isEmpty {
                        Text(store.workspaceAppearanceMessage).font(.caption).textSelection(.enabled)
                    }
                }.padding(22).studioPanel(radius: 18)
            }.frame(maxWidth: 820, alignment: .leading).padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityIdentifier("page.dot")
    }

    private var preview: some View {
        VStack(spacing: store.workspaceAppearance.dotSpacing) {
            Label("dot", systemImage: "circle.circle.fill")
                .font(.title3.weight(.semibold)).padding(.bottom, 10)
            bubble("Hey! I’m your dot.", mine: false)
            bubble("Message or call me anytime. I’ll keep things moving and check in with updates or questions.", mine: false)
            bubble("Thanks! Keep me posted.", mine: true)
            HStack(spacing: 12) {
                Image(systemName: "plus")
                Text("Send a message").foregroundStyle(.white.opacity(0.65))
                Spacer()
                Image(systemName: "arrow.up").padding(8).background(.blue, in: Circle())
            }.padding(14).background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.22)))
        }.padding(26).frame(maxWidth: .infinity)
            .background {
                GeometryReader { geometry in
                    ZStack {
                        if let theme = store.selectedTheme {
                            ThemeArtworkView(theme: theme, showOverlay: false)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        Color.black.opacity(store.workspaceAppearance.dotBackdropDim)
                        RadialGradient(colors: [.blue.opacity(0.30), .clear], center: .topLeading, startRadius: 0, endRadius: 550)
                    }
                }.allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.20)))
            .accessibilityLabel("Dot conversation preview")
    }

    private func bubble(_ text: String, mine: Bool) -> some View {
        let hex = mine ? store.workspaceAppearance.dotUserBubbleColor : store.workspaceAppearance.dotBubbleColor
        return HStack {
            if mine { Spacer(minLength: 70) }
            Text(text).font(.body).foregroundStyle(foreground(hex))
                .padding(.horizontal, 18).padding(.vertical, 13)
                .background(LinearGradient(colors: [Color(hex: hex).opacity(0.94), Color(hex: hex).opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: store.workspaceAppearance.dotRadius))
                .shadow(color: Color(hex: hex).opacity(0.20), radius: 12, y: 5)
                .overlay(RoundedRectangle(cornerRadius: store.workspaceAppearance.dotRadius).strokeBorder(.white.opacity(0.16)))
                .frame(maxWidth: 550, alignment: mine ? .trailing : .leading)
            if !mine { Spacer(minLength: 70) }
        }
    }

    private func foreground(_ hex: String) -> Color {
        let value = Int(hex.dropFirst(), radix: 16) ?? 0
        let luminance = Double((value >> 16) & 255) * 0.299 + Double((value >> 8) & 255) * 0.587 + Double(value & 255) * 0.114
        return luminance > 155 ? Color(hex: "#111827") : .white
    }

    private func color(_ hex: Binding<String>) -> Binding<Color> {
        Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = $0.hexDescription })
    }

    private func adjustment(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1, percent: Bool = false) -> some View {
        HStack {
            Text(title).frame(width: 140, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(percent ? "\(Int(value.wrappedValue * 100))%" : "\(Int(value.wrappedValue)) px").monospacedDigit().frame(width: 48)
        }
    }
}
