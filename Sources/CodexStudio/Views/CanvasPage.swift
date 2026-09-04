import SwiftUI

struct CanvasPage: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageHeader
                hero
                featuredStrip
                quickSwitch
                sourceFooter
            }
            .padding(.horizontal, StudioLayoutMetrics.pageHorizontalPadding)
            .padding(.top, 26)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private var pageHeader: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Canvas")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioColor.cyan)
                Text("A calmer way to shape Codex.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(StudioColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("Stage a world, tune it in context, and send it to Codex in one deliberate move.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(StudioColor.textMuted)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                StudioPill(title: "\(store.themes.count) themes", tint: StudioColor.violet, symbol: "square.stack.3d.up")
                StudioPill(title: store.runtime.connection.label, tint: store.connectionColor, symbol: "bolt.fill")
            }
        }
    }

    private var hero: some View {
        // Keep the aura as a sibling behind the finite card, matching the
        // Themes spotlight. Putting it on the card's background and clipping
        // the result traps the blurred artwork underneath the opaque preview,
        // which removes the visible glow around the card.
        ZStack {
            if let selectedTheme = store.selectedTheme {
                ThemeAdaptiveGlow(
                    theme: selectedTheme,
                    height: StudioLayoutMetrics.canvasHeroHeight,
                    compact: false
                )
            }

            heroSurface
        }
        .frame(maxWidth: .infinity)
        .frame(height: StudioLayoutMetrics.canvasHeroHeight)
    }

    private var heroSurface: some View {
        ZStack {
            if let selectedTheme = store.selectedTheme {
                ThemeArtworkView(theme: selectedTheme, animated: store.motionEnabled, showOverlay: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: StudioLayoutMetrics.canvasHeroHeight)
            } else {
                LinearGradient(colors: [StudioColor.inkSoft, StudioColor.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(maxWidth: .infinity)
                    .frame(height: StudioLayoutMetrics.canvasHeroHeight)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.42), Color.black.opacity(0.12), Color.black.opacity(0.76)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        // Establish the card geometry before measuring the overlay. The
        // artwork's GeometryReader must not receive the ScrollView's
        // unbounded vertical proposal on macOS 26.
        .frame(maxWidth: .infinity)
        .frame(height: StudioLayoutMetrics.canvasHeroHeight)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    StudioPill(title: "Selected world", tint: StudioColor.cyan, symbol: "cursorarrow.rays")
                    Spacer(minLength: 12)
                    if let theme = store.selectedTheme {
                        StudioPill(title: theme.sourceLabel, tint: theme.isInstalled ? StudioColor.mint : StudioColor.textMuted, symbol: theme.isInstalled ? "checkmark.seal" : "eye")
                    }
                }

                Spacer(minLength: 18)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 24) {
                        heroCopy
                        Spacer(minLength: 18)
                        heroFacts
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        heroCopy
                        heroFacts
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: store.selectedTheme.map { Color(hex: $0.palette.accent).opacity(0.14) } ?? .black.opacity(0.18), radius: 24, y: 12)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.selectedTheme?.name ?? "Choose a theme")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                Text(store.selectedTheme?.shortDescription ?? "Your local catalog is loading.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(3)
                    .frame(maxWidth: 640, alignment: .leading)
            }

            HStack(spacing: 8) {
                Button {
                    store.applySelectedTheme()
                } label: {
                    Label(store.isApplying ? "Applying…" : "Apply to Codex", systemImage: store.isApplying ? "arrow.triangle.2.circlepath" : "bolt.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(StudioColor.cyan)
                .disabled(store.isApplying || store.selectedTheme?.isInstalled != true)

                Button {
                    store.selectSection(.editor)
                    store.previewMode = .home
                } label: {
                    Label("Open live editor", systemImage: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .tint(.white)
            }
        }
    }

    private var heroFacts: some View {
        HStack(spacing: 16) {
            HeroFact(label: "Source", value: store.selectedTheme?.sourceLabel ?? "—")
            HeroFact(label: "Palette", value: store.selectedTheme?.category ?? "—")
            HeroFact(label: "Safe area", value: store.selectedTheme?.safeArea.capitalized ?? "—")
            if let theme = store.selectedTheme {
                ThemeSwatch(theme: theme, size: 34)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.white.opacity(0.17), lineWidth: 1)
        }
    }

    private var featuredStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                title: store.sourceSummary.curatedCount > 0 ? "Curated directions" : "Local directions",
                detail: "Distinct starting points for the live editor"
            )
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(store.featuredThemes) { theme in
                        FeaturedThemeCard(theme: theme, isSelected: store.selectedTheme?.id == theme.id) {
                            store.selectTheme(theme)
                        }
                    }
                }
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var quickSwitch: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(title: "Quick switch", detail: "Jump between installed themes without leaving Canvas")
            LazyVGrid(columns: ThemeGalleryMetrics.columns, spacing: 12) {
                ForEach(store.quickSwitchThemes) { theme in
                    QuickSwitchCard(
                        theme: theme,
                        isActive: store.runtime.activeThemeID == theme.id,
                        isSelected: store.selectedTheme?.id == theme.id,
                        select: { store.selectTheme(theme) },
                        apply: {
                            store.selectTheme(theme)
                            store.applySelectedTheme()
                        }
                    )
                }
            }
        }
    }

    private var sourceFooter: some View {
        HStack(spacing: 13) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(StudioColor.cyan)
                .frame(width: 35, height: 35)
                .background(StudioColor.cyan.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Your library is ready offline")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                Text("\(store.sourceSummary.localCount) installed · \(store.sourceSummary.curatedCount) curated · local sources checked at launch")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(StudioColor.textMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button("Browse library") {
                store.selectSection(.library)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(StudioColor.cyan)
            .buttonStyle(StudioPressableButtonStyle())
        }
        .padding(14)
        .studioPanel(radius: 15, fill: Color.white.opacity(0.035))
    }

    private func sectionTitle(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StudioColor.text)
            Text(detail)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(StudioColor.textFaint)
            Spacer()
        }
    }
}

private struct HeroFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.60))
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
    }
}

private struct FeaturedThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ThemeArtworkView(theme: theme, showOverlay: false)
                        .frame(width: 196, height: 106)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(StudioColor.cyan, StudioColor.ink)
                            .padding(8)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StudioColor.text)
                        .lineLimit(1)
                    Text(theme.category)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(StudioColor.textFaint)
                }
            }
            .padding(10)
            .frame(width: 216, alignment: .leading)
            .background(isSelected ? StudioColor.cyan.opacity(0.09) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(isSelected ? StudioColor.cyan.opacity(0.48) : StudioColor.line, lineWidth: 1)
            }
        }
        .buttonStyle(StudioPressableButtonStyle())
    }
}

private struct QuickSwitchCard: View {
    let theme: Theme
    let isActive: Bool
    let isSelected: Bool
    let select: () -> Void
    let apply: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: select) {
                ThemeArtworkView(theme: theme, showOverlay: false)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(StudioPressableButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(theme.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    ThemeSwatch(theme: theme, size: 13)
                    Text(isActive ? "Active in Codex" : theme.category)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(isActive ? StudioColor.mint : StudioColor.textFaint)
                }
            }

            Spacer(minLength: 0)

            Button(action: apply) {
                Image(systemName: isActive ? "checkmark" : "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isActive ? StudioColor.mint : (isSelected ? StudioColor.cyan : StudioColor.textMuted))
                    .frame(width: 28, height: 28)
                    .background(.thinMaterial, in: Circle())
                    .overlay {
                        Circle().strokeBorder(StudioColor.line, lineWidth: 1)
                    }
            }
            .buttonStyle(StudioPressableButtonStyle())
            .help("Apply \(theme.name)")
        }
        .padding(10)
        .studioPanel(radius: 14, fill: isSelected ? StudioColor.cyan.opacity(0.075) : Color.white.opacity(0.035))
    }
}
