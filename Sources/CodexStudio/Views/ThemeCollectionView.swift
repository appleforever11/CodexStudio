import SwiftUI

enum ThemeGalleryMetrics {
    static let sectionSpacing: CGFloat = 28
    static let cardSpacing: CGFloat = 20
    static let horizontalPadding: CGFloat = StudioLayoutMetrics.pageHorizontalPadding
    static let verticalPadding: CGFloat = StudioLayoutMetrics.pageVerticalPadding

    static var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 264, maximum: 370), spacing: cardSpacing, alignment: .top)]
    }
}

struct ThemeCollectionView: View {
    @EnvironmentObject private var store: StudioStore
    let themes: [Theme]
    let layout: ThemeLayout

    var body: some View {
        if layout == .list {
            LazyVStack(spacing: 10) {
                ForEach(themes) { theme in
                    ThemeAtlasRow(theme: theme, isSelected: store.selectedTheme?.id == theme.id)
                }
            }
        } else {
            LazyVGrid(columns: ThemeGalleryMetrics.columns, spacing: ThemeGalleryMetrics.cardSpacing) {
                ForEach(themes) { theme in
                    ThemeAtlasCard(theme: theme, isSelected: store.selectedTheme?.id == theme.id)
                }
            }
        }
    }
}
