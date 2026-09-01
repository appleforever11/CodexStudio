import SwiftUI

struct PaletteRow: View {
    let label: String
    let color: Color
    let value: String

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(StudioColor.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(StudioColor.textFaint)
        }
    }
}
