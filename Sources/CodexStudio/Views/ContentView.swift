import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        GeometryReader { viewport in
            ZStack(alignment: .topLeading) {
                StudioBackdrop(theme: store.selectedTheme)

                // Pin the split to the finite window viewport. A vertical
                // ScrollView can otherwise make the HStack taller than the
                // visible client area on macOS 26, which vertically centers
                // and clips both the sidebar header/footer and the page header.
                HStack(spacing: 0) {
                    StudioSidebar()
                        .frame(width: 248)

                    Rectangle()
                        .fill(StudioColor.line)
                        .frame(width: 1)

                    mainSurface
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
