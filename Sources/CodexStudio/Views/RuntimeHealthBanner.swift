import SwiftUI

struct RuntimeHealthBanner: View {
    @EnvironmentObject private var store: StudioStore

    private var tint: Color {
        switch store.runtime.connection {
        case .offline: .orange
        case .unavailable: StudioColor.violet
        case .connected: StudioColor.mint
        }
    }

    private var title: String {
        switch store.runtimePhase {
        case .checking: return "Checking the local Codex runtime"
        case .applying: return "Applying and verifying the selected theme"
        case .recovering: return "Recovering the Codex runtime"
        case .failed: break
        case .idle: break
        }
        switch store.runtime.connection {
        case .offline: return "Codex is waiting to reconnect"
        case .unavailable: return "Live Codex runtime needs attention"
        case .connected: return "Codex is ready"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: store.runtimePhase == .idle && store.runtime.connection == .offline
                ? "wifi.exclamationmark"
                : store.runtimePhase.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                Text(store.runtime.message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(StudioColor.textMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            if store.isRefreshingRuntime || store.isApplying {
                ProgressView()
                    .controlSize(.small)
                    .tint(tint)
            } else {
                Button("Retry") {
                    store.refreshRuntime()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(tint)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .studioPanel(radius: 14, fill: tint.opacity(0.065))
        .accessibilityElement(children: .contain)
    }
}
