import SwiftUI

struct SettingsLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(StudioColor.textFaint)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(StudioColor.textMuted)
                .lineLimit(1)
        }
    }
}

struct SettingsSourceRow: View {
    let title: String
    let detail: String
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                Spacer()
                Text(detail)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(StudioColor.cyan)
            }
            Text(path)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(StudioColor.textFaint)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
}

struct SettingsCardHeading: View {
    let title: String
    let symbol: String
    let tint: Color
    init(_ title: String, symbol: String, tint: Color) {
        self.title = title; self.symbol = symbol; self.tint = tint
    }
    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
    }
}
