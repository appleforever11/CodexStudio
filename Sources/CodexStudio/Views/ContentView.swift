import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ZStack {
            StudioBackdrop(theme: store.selectedTheme)

            NavigationSplitView {
                StudioSidebar()
                    .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 290)
            } detail: {
                VStack(spacing: 0) {
                    StudioCommandBar()
                    Divider()
                        .overlay(StudioColor.line)
                    mainSurface
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .navigationSplitViewStyle(.balanced)
            // Reserve the native titlebar inside the split view's layout
            // rather than adding outside padding that can push its footer
            // below the window edge on macOS 26.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 54)
            }
            .background(.clear)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(StudioColor.lineStrong, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.30), radius: 30, y: 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 1120, minHeight: 700)
        .preferredColorScheme(.dark)
        .task {
            await store.bootstrap()
        }
        .overlay(alignment: .bottomTrailing) {
            if let notice = store.notice {
                NoticeToast(message: notice)
                    .padding(22)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: store.notice)
    }

    @ViewBuilder
    private var mainSurface: some View {
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
