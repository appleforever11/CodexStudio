import SwiftUI

struct PreviewComposer: View {
    @EnvironmentObject private var store: StudioStore
    let values: PreviewThemeValues

    var body: some View {
        PreviewRegion(surface: .composer, values: values) {
            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(values.muted)
                Text("Ask Codex anything…")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(values.muted)
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(values.muted)
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(values.accent)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(values.panelAlt.opacity(0.90), in: RoundedRectangle(cornerRadius: store.draftRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: store.draftRadius, style: .continuous).stroke(values.accent.opacity(0.28), lineWidth: 1))
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }
}
