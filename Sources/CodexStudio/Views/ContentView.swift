import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { viewport in
            ZStack(alignment: .topLeading) {
                StudioBackdrop(theme: store.selectedTheme)
                StudioWindowChromeConfigurator()
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    StudioWindowHeader()

                    // Pin the split to the finite window viewport. A vertical
                    // ScrollView can otherwise make the HStack taller than the
                    // visible client area on macOS 26, which vertically centers
                    // and clips both the sidebar header/footer and the page header.
                    HStack(spacing: 0) {
                        StudioSidebar()
                            .frame(width: StudioLayoutMetrics.sidebarWidth)

                        Rectangle()
                            .fill(StudioColor.line)
                            .frame(width: 1)

                        mainSurface
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(
                        width: viewport.size.width,
                        height: max(0, viewport.size.height - StudioWindowHeader.height),
                        alignment: .topLeading
                    )
                }
                .frame(
                    width: viewport.size.width,
                    height: viewport.size.height,
                    alignment: .topLeading
                )
                .background(.clear)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(StudioColor.lineStrong, lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.30), radius: 30, y: 14)
            }
            .frame(
                width: viewport.size.width,
                height: viewport.size.height,
                alignment: .topLeading
            )
        }
        // Let the two-pane surface reach both content edges of the window.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(minWidth: 1120, minHeight: 700)
        .task {
            await store.bootstrap()
            await store.monitorRuntime()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // A sleep, fast user switch, or Codex update can invalidate the
            // loopback process while Studio itself remains open.
            store.refreshRuntime()
        }
        .overlay(alignment: .bottomTrailing) {
            if let notice = store.notice {
                NoticeToast(message: notice)
                    .padding(22)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: store.notice)
        // The window uses a transparent full-size titlebar. The shared Studio
        // header must therefore occupy the titlebar's top safe-area region so
        // the traffic lights and header are one continuous surface.
        .ignoresSafeArea(.container, edges: .top)
    }

    @ViewBuilder
    private var mainSurface: some View {
        VStack(spacing: 0) {
            if !store.isLoading, store.runtime.connection != .connected {
                RuntimeHealthBanner()
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
            }

            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch store.section {
        case .canvas:
            CanvasPage()
        case .editor:
            LiveEditorPage()
        case .themes:
            ThemesPage()
        case .library:
            LibraryPage()
        case .settings:
            PreferencesPage()
        }
    }
}

struct NoticeToast: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(StudioColor.mint)
        }
        .foregroundStyle(StudioColor.text)
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .frame(maxWidth: 360, alignment: .leading)
        .studioPanel(radius: 14, fill: StudioColor.inkRaised.opacity(0.78))
        .shadow(color: .black.opacity(0.32), radius: 20, y: 8)
    }
}
