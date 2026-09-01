import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ZStack {
            StudioBackdrop(theme: store.selectedTheme)

            HStack(spacing: 0) {
                StudioSidebar()
                    .frame(width: 248)

                Rectangle()
                    .fill(StudioColor.line)
                    .frame(width: 1)

                mainSurface
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            // The titlebar is transparent over the window content on recent
            // macOS releases. Reserve only its actual compact height so the
            // sidebar and detail pane begin on the same baseline.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 26)
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
        // Let the two-pane surface reach the window's left and right edges;
        // keep only the vertical breathing room around the native chrome.
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 1120, minHeight: 700)
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
