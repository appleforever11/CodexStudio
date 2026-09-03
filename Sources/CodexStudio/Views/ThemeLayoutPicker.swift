import SwiftUI

struct ThemeLayoutPicker: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ThemeLayout.allCases) { layout in
                Button {
                    store.setThemeLayout(layout)
                } label: {
                    Image(systemName: layout.systemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(store.themeLayout == layout ? StudioColor.text : StudioColor.textFaint)
                        .frame(width: 32, height: 28)
                        .background(
                            store.themeLayout == layout ? Color.white.opacity(0.13) : .clear,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                }
                .buttonStyle(StudioPressableButtonStyle())
                .help(layout.label)
                .accessibilityLabel(layout.label)
                .accessibilityAddTraits(store.themeLayout == layout ? .isSelected : [])
            }
        }
        .padding(2)
        .frame(width: 72, height: 34)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(StudioColor.line, lineWidth: 1)
        }
        .help("Choose grid or list view")
        .accessibilityLabel("Gallery layout")
    }
}
