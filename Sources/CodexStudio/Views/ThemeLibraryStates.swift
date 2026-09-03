import SwiftUI

struct ThemeAtlasErrorState: View {
    let title: String
    let detail: String
    let retry: () -> Void

    @EnvironmentObject private var store: StudioStore

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .frame(width: 54, height: 54)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudioColor.text)

            Text(detail)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(StudioColor.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)

            Button {
                retry()
            } label: {
                Label("Re-scan local sources", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioColor.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(StudioColor.spectrum, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(StudioPressableButtonStyle())
            .disabled(store.isLoading)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .studioPanel(radius: 18, fill: Color.orange.opacity(0.045))
        .accessibilityElement(children: .contain)
    }
}
