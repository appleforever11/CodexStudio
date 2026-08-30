import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ZStack {
            StudioColor.ink.ignoresSafeArea()

            HStack(spacing: 0) {
                StudioSidebar()
                Rectangle()
                    .fill(StudioColor.line)
                    .frame(width: 1)
                mainSurface
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 1120, minHeight: 700)
        .preferredColorScheme(.dark)
        .task {
            await store.bootstrap()
        }
        .overlay(alignment: .bottomTrailing) {
            if let notice = store.notice {
                NoticeToast(message: notice)
                    .padding(24)
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
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(StudioColor.cyan)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(StudioColor.text)
                .lineLimit(2)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .frame(maxWidth: 360, alignment: .leading)
        .studioPanel(radius: 14, fill: StudioColor.inkSoft.opacity(0.96))
        .shadow(color: .black.opacity(0.38), radius: 20, y: 8)
    }
}
