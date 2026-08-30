import SwiftUI

struct ThemesPage: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            libraryHeader(
                kicker: "THEME LIBRARY",
                title: "Choose a visual direction.",
                detail: "Curated compositions up front. Your entire managed library, one search away."
            )
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 20)

            HStack(spacing: 12) {
                ThemeSearchField()
                Picker("Filter", selection: $store.themeFilter) {
                    ForEach(ThemeFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 360)
                Button {
                    store.selectSection(.library)
                } label: {
                    Label("My library", systemImage: "square.stack.3d.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudioColor.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 20)

            HStack(alignment: .top, spacing: 20) {
                ScrollView {
                    if store.filteredThemes.isEmpty {
                        EmptyThemeSearchView()
                            .frame(maxWidth: .infinity, minHeight: 360)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 205, maximum: 280), spacing: 14)], spacing: 14) {
                            ForEach(store.filteredThemes) { theme in
                                ThemeCard(theme: theme, isSelected: store.selectedTheme?.id == theme.id) {
                                    store.selectTheme(theme)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if let selectedTheme = store.selectedTheme {
                    ThemeDetailPanel(theme: selectedTheme)
                        .frame(width: 310)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 34)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(pageBackground)
    }

    private var pageBackground: some View {
        ZStack {
            StudioColor.ink
            LinearGradient(colors: [StudioColor.violet.opacity(0.025), .clear, StudioColor.cyan.opacity(0.025)], startPoint: .topTrailing, endPoint: .bottomLeading)
        }
    }
}

struct LibraryPage: View {
    @EnvironmentObject private var store: StudioStore

    private var localThemes: [Theme] {
        store.themes.filter { $0.origin == .local || $0.origin == .wallBuddy }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                libraryHeader(
                    kicker: "YOUR COLLECTION",
                    title: "Everything you’ve brought home.",
                    detail: "Codex Studio reads the existing managed library in place, so switching stays fast and reversible."
                )
                Spacer()
                Button {
                    store.importThemeFolder()
                } label: {
                    Label("Import theme folder", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(StudioColor.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(StudioColor.cyan, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 18)

            HStack(spacing: 12) {
                ThemeSearchField()
                StudioPill(title: "\(localThemes.count) local themes", tint: StudioColor.violet, symbol: "shippingbox")
                if store.sourceSummary.wallBuddyCount > 0 {
                    StudioPill(title: "\(store.sourceSummary.wallBuddyCount) WallBuddy assets", tint: .pink, symbol: "photo.on.rectangle")
                } else {
                    StudioPill(title: "WallBuddy checked", tint: StudioColor.textFaint, symbol: "checkmark")
                }
                Spacer()
                Button {
                    store.revealManagedThemes()
                } label: {
                    Label("Reveal folder", systemImage: "folder")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudioColor.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 20)

            HStack(alignment: .top, spacing: 20) {
                ScrollView {
                    let visibleThemes = localThemes.filter { theme in
                        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        return query.isEmpty || [theme.name, theme.author, theme.category, theme.description].joined(separator: " ").lowercased().contains(query)
                    }
                    if visibleThemes.isEmpty {
                        EmptyLibraryView()
                            .frame(maxWidth: .infinity, minHeight: 350)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 205, maximum: 280), spacing: 14)], spacing: 14) {
                            ForEach(visibleThemes) { theme in
                                ThemeCard(theme: theme, isSelected: store.selectedTheme?.id == theme.id) {
                                    store.selectTheme(theme)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if let selectedTheme = store.selectedTheme {
                    ThemeDetailPanel(theme: selectedTheme)
                        .frame(width: 310)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 34)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(StudioColor.ink)
    }
}

private func libraryHeader(kicker: String, title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(kicker)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.7)
            .foregroundStyle(StudioColor.cyan)
        Text(title)
            .font(.system(size: 27, weight: .bold, design: .rounded))
            .foregroundStyle(StudioColor.text)
        Text(detail)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(StudioColor.textMuted)
            .lineLimit(2)
    }
}

private struct ThemeSearchField: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioColor.textFaint)
            TextField("Search themes, moods, or makers", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
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
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 330)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(StudioColor.line, lineWidth: 1))
    }
}

struct ThemeCard: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack(alignment: .topTrailing) {
                ThemeArtworkView(theme: theme, animated: isHovered && store.motionEnabled)
                    .frame(height: 142)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                HStack(spacing: 7) {
                    if theme.isInstalled {
                        StudioPill(title: "Ready", tint: .green, symbol: "checkmark")
                    }
                    Button {
                        store.toggleFavorite(theme)
                    } label: {
                        Image(systemName: theme.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.isFavorite ? .yellow : .white.opacity(0.82))
                            .frame(width: 28, height: 28)
                            .background(.black.opacity(0.30), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(theme.isFavorite ? "Remove favorite" : "Add favorite")
                }
                .padding(9)
            }
            HStack(spacing: 9) {
                ThemeSwatch(theme: theme, size: 25)
                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(StudioColor.text)
                        .lineLimit(1)
                    Text("\(theme.category) · \(theme.author)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(StudioColor.textFaint)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
        .padding(10)
        .background(isSelected ? StudioColor.cyan.opacity(0.085) : Color.white.opacity(isHovered ? 0.065 : 0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isSelected ? StudioColor.cyan.opacity(0.52) : (isHovered ? StudioColor.lineStrong : StudioColor.line), lineWidth: 1))
        .studioHoverScale(isHovered)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(theme.name), \(theme.category)\(theme.isInstalled ? ", ready" : ", preview")")
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(theme.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                store.toggleFavorite(theme)
            }
            if theme.isInstalled {
                Button("Apply to Codex") {
                    store.selectTheme(theme)
                    store.applySelectedTheme()
                }
            }
        }
    }
}

struct ThemeDetailPanel: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                ThemeArtworkView(theme: theme, animated: store.motionEnabled)
                    .frame(height: 174)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(theme.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(StudioColor.text)
                            Text("by \(theme.author)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(StudioColor.textMuted)
                        }
                        Spacer()
                        ThemeSwatch(theme: theme, size: 30)
                    }
                    Text(theme.shortDescription)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(StudioColor.textMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 7) {
                    StudioPill(title: theme.category, tint: Color(hex: theme.palette.accent), symbol: "circle.fill")
                    StudioPill(title: theme.appearance, tint: StudioColor.textMuted)
                }

                Button {
                    store.selectTheme(theme)
                    store.applySelectedTheme()
                } label: {
                    HStack {
                        Image(systemName: store.runtime.activeThemeID == theme.id ? "checkmark" : "bolt.fill")
                        Text(store.runtime.activeThemeID == theme.id ? "Active in Codex" : "Apply to Codex")
                        Spacer()
                        if !theme.isInstalled { Text("Preview") }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.isInstalled ? StudioColor.ink : StudioColor.textMuted)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(theme.isInstalled ? StudioColor.cyan : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!theme.isInstalled || store.isApplying)

                Button {
                    store.selectTheme(theme)
                    store.selectSection(.editor)
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Edit in live canvas")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 11) {
                    Text("PALETTE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(StudioColor.textFaint)
                    PaletteRow(label: "Accent", color: Color(hex: theme.palette.accent), value: theme.palette.accent)
                    PaletteRow(label: "Surface", color: Color(hex: theme.palette.panel), value: theme.palette.panel)
                    PaletteRow(label: "Canvas", color: Color(hex: theme.palette.background), value: theme.palette.background)
                }
                .padding(.top, 3)

                VStack(alignment: .leading, spacing: 6) {
                    DetailLine(label: "Source", value: theme.sourceLabel)
                    DetailLine(label: "Task mode", value: theme.taskMode.capitalized)
                    DetailLine(label: "Safe area", value: theme.safeArea.capitalized)
                }
                .padding(.top, 2)
            }
            .padding(15)
        }
        .scrollIndicators(.hidden)
        .studioPanel(radius: 20, fill: StudioColor.inkRaised.opacity(0.72))
    }
}

struct PaletteRow: View {
    let label: String
    let color: Color
    let value: String

    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioColor.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(StudioColor.textFaint)
        }
    }
}

private struct DetailLine: View {
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
        }
    }
}

private struct EmptyThemeSearchView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No themes match", systemImage: "magnifyingglass")
        } description: {
            Text("Try a different mood, category, or maker.")
        }
        .foregroundStyle(StudioColor.textMuted)
    }
}

private struct EmptyLibraryView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Your local shelf is empty", systemImage: "square.stack.3d.up")
        } description: {
            Text("Import an extracted theme folder to start building your own collection.")
        }
        .foregroundStyle(StudioColor.textMuted)
    }
}
