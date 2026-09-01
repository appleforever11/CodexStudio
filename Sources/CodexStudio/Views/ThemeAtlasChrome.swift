import SwiftUI

struct ThemeAtlasHeader: View {
    let eyebrow: String
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            ZStack {
                Circle()
                    .fill(StudioColor.cyan.opacity(0.13))
                Circle()
                    .strokeBorder(StudioColor.cyan.opacity(0.22), lineWidth: 1)
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(StudioColor.cyan)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(StudioColor.cyan)
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(StudioColor.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text(detail)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(StudioColor.textMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ThemeSpotlight: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme
    var compact = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                ThemeArtworkView(theme: theme, animated: store.motionEnabled, showOverlay: false)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                LinearGradient(
                    colors: [Color.black.opacity(0.86), Color.black.opacity(0.44), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Group {
                    if proxy.size.width < (compact ? 860 : 980) {
                        VStack(alignment: .leading, spacing: 11) {
                            spotlightCopy
                            spotlightActions
                            HStack {
                                Spacer(minLength: 0)
                                spotlightDetails
                            }
                        }
                    } else {
                        HStack(alignment: .bottom, spacing: 24) {
                            VStack(alignment: .leading, spacing: compact ? 9 : 12) {
                                spotlightCopy
                                spotlightActions
                            }
                            Spacer(minLength: 16)
                            spotlightDetails
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(compact ? 18 : 22)
            }
        }
        .frame(height: compact ? 224 : 276)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.17), lineWidth: 1)
        }
        .shadow(color: Color(hex: theme.palette.accent).opacity(0.14), radius: 24, y: 12)
    }

    private var spotlightCopy: some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            HStack(spacing: 7) {
                StudioPill(title: "Studio spotlight", tint: StudioColor.cyan, symbol: "sparkles")
                StudioPill(title: theme.category, tint: Color(hex: theme.palette.accent))
                StudioPill(title: theme.appearance, tint: StudioColor.textMuted)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(theme.name)
                    .font(.system(size: compact ? 25 : 32, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(theme.shortDescription)
                    .font(.system(size: compact ? 11 : 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineSpacing(2)
                    .lineLimit(compact ? 2 : 3)
                    .frame(maxWidth: 610, alignment: .leading)
            }
        }
        .layoutPriority(1)
    }

    @ViewBuilder
    private var spotlightActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 9) {
                applyButton
                liveLabButton
                favoriteButton
                sourceButton
            }

            HStack(spacing: 9) {
                applyButton
                liveLabButton
                favoriteButton
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    applyButton
                    liveLabButton
                }
                HStack(spacing: 9) {
                    favoriteButton
                    sourceButton
                }
            }
        }
    }

    private var applyButton: some View {
        Button {
            store.selectTheme(theme)
            store.applySelectedTheme()
        } label: {
            Label(
                store.runtime.activeThemeID == theme.id ? "Active in Codex" : "Apply to Codex",
                systemImage: store.runtime.activeThemeID == theme.id ? "checkmark" : "bolt.fill"
            )
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(StudioColor.ink)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(StudioColor.spectrum, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!theme.isInstalled || store.isApplying)
        .opacity(theme.isInstalled ? 1 : 0.46)
    }

    private var liveLabButton: some View {
        Button {
            store.selectTheme(theme)
            store.selectSection(.editor)
        } label: {
            Label("Open live lab", systemImage: "slider.horizontal.3")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var favoriteButton: some View {
        Button {
            store.toggleFavorite(theme)
        } label: {
            Image(systemName: theme.isFavorite ? "star.fill" : "star")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.isFavorite ? StudioColor.amber : .white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sourceButton: some View {
        if let sourceURL = theme.sourceURL.flatMap(URL.init(string:)) {
            Link(destination: sourceURL) {
                Label("Source", systemImage: "arrow.up.right.square")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(height: 38)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var spotlightDetails: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(theme.collection.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
            AtlasPaletteStrip(theme: theme)
            Text(theme.sourceLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.isInstalled ? StudioColor.mint : .white.opacity(0.62))
        }
        .frame(width: 180, alignment: .trailing)
    }
}

struct ThemeAtlasControls: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                AtlasSearchField()
                ThemeFilterDeck()
                sortMenu
                libraryButton
            }

            VStack(alignment: .leading, spacing: 10) {
                AtlasSearchField()
                HStack(spacing: 10) {
                    ThemeFilterDeck()
                    sortMenu
                    libraryButton
                }
            }
        }
        .padding(8)
        .studioPanel(radius: 14, fill: Color.white.opacity(0.025))
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort themes", selection: $store.themeSortOrder) {
                ForEach(ThemeSortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
        } label: {
            Label(store.themeSortOrder.label, systemImage: "arrow.up.arrow.down")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(StudioColor.textMuted)
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(StudioColor.line, lineWidth: 1)
                }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var libraryButton: some View {
        Button {
            store.selectSection(.library)
        } label: {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StudioColor.cyan)
                .frame(width: 34, height: 34)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(StudioColor.line, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help("Open installed library")
    }
}

struct AtlasSearchField: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioColor.textFaint)
            TextField("Search names, moods, collections…", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioColor.text)
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(StudioColor.textFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(minWidth: 220, maxWidth: 430, minHeight: 34)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(StudioColor.line, lineWidth: 1)
        }
    }
}

struct ThemeCategoryRail: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(store.themeCategories, id: \.self) { category in
                    Button {
                        store.selectedThemeCategory = category
                    } label: {
                        HStack(spacing: 6) {
                            if category == "All" {
                                Image(systemName: "circle.grid.3x3.fill")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Text(category)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(store.selectedThemeCategory == category ? StudioColor.ink : StudioColor.textMuted)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(
                            store.selectedThemeCategory == category ? AnyShapeStyle(StudioColor.spectrum) : AnyShapeStyle(.thinMaterial),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(store.selectedThemeCategory == category ? Color.white.opacity(0.20) : StudioColor.line, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ThemeFilterDeck: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ThemeFilter.allCases) { filter in
                Button {
                    store.themeFilter = filter
                } label: {
                    Text(filter.label)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(store.themeFilter == filter ? StudioColor.text : StudioColor.textFaint)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(
                            store.themeFilter == filter ? Color.white.opacity(0.11) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(StudioColor.line, lineWidth: 1)
        }
        .fixedSize()
    }
}

private struct AtlasPaletteStrip: View {
    let theme: Theme

    var body: some View {
        HStack(spacing: 5) {
            paletteDot(theme.palette.accent)
            paletteDot(theme.palette.accentAlt)
            paletteDot(theme.palette.secondary)
            paletteDot(theme.palette.panel)
            paletteDot(theme.palette.background)
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
    }

    private func paletteDot(_ value: String) -> some View {
        Circle()
            .fill(Color(hex: value))
            .frame(width: 15, height: 15)
            .overlay(Circle().stroke(Color.white.opacity(0.26), lineWidth: 1))
    }
}
