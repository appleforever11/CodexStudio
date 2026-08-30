import SwiftUI

struct CanvasPage: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader
                hero
                featuredStrip
                quickSwitch
                sourceFooter
            }
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .background(canvasBackground)
    }

    private var pageHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("CANVAS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(StudioColor.cyan)
                Text("Your workspace, art-directed.")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(StudioColor.text)
                Text("Shape a visual system, preview it in motion, and send it to Codex in one deliberate move.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(StudioColor.textMuted)
            }
            Spacer()
            HStack(spacing: 10) {
                StudioPill(title: "\(store.themes.count) themes", tint: StudioColor.violet, symbol: "square.stack.3d.up")
                StudioPill(title: store.runtime.connection.label, tint: store.connectionColor, symbol: "bolt.fill")
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                StudioPill(title: "Selected direction", tint: StudioColor.cyan, symbol: "cursorarrow.rays")
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.selectedTheme?.name ?? "Choose a theme")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioColor.text)
                        .lineLimit(2)
                    Text(store.selectedTheme?.shortDescription ?? "Your local catalog is loading.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(StudioColor.textMuted)
                        .lineLimit(3)
                }
                HStack(spacing: 10) {
                    Button {
                        store.applySelectedTheme()
                    } label: {
                        Label(store.isApplying ? "Applying…" : "Apply to Codex", systemImage: store.isApplying ? "arrow.triangle.2.circlepath" : "bolt.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(StudioColor.ink)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 11)
                            .background(StudioColor.cyan, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isApplying || store.selectedTheme?.isInstalled != true)
                    .opacity(store.selectedTheme?.isInstalled == true ? 1 : 0.45)

                    Button {
                        store.selectSection(.editor)
                        store.previewMode = .home
                    } label: {
                        Label("Open live editor", systemImage: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(StudioColor.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.white.opacity(0.13), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 16) {
                    HeroFact(label: "Source", value: store.selectedTheme?.sourceLabel ?? "—")
                    HeroFact(label: "Palette", value: store.selectedTheme?.category ?? "—")
                    HeroFact(label: "Safe area", value: store.selectedTheme?.safeArea.capitalized ?? "—")
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .padding(28)

            ZStack {
                if let selectedTheme = store.selectedTheme {
                    ThemeArtworkView(theme: selectedTheme, animated: store.motionEnabled)
                } else {
                    LinearGradient(colors: [StudioColor.inkSoft, StudioColor.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.76)], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: 335)
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(StudioColor.cyan)
                    Text("ARTWORK")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(18)
            }
            .clipped()
        }
        .frame(minHeight: 282)
        .studioPanel(radius: 22, fill: StudioColor.inkRaised.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var featuredStrip: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle(title: "Curated directions", detail: "Distinct starting points for the live editor")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 13) {
                    ForEach(store.featuredThemes) { theme in
                        FeaturedThemeCard(theme: theme, isSelected: store.selectedTheme?.id == theme.id) {
                            store.selectTheme(theme)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var quickSwitch: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle(title: "Quick switch", detail: "Jump between installed themes without leaving the canvas")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)], spacing: 13) {
                ForEach(store.quickSwitchThemes) { theme in
                    QuickSwitchCard(theme: theme, isActive: store.runtime.activeThemeID == theme.id, isSelected: store.selectedTheme?.id == theme.id) {
                        store.selectTheme(theme)
                    } apply: {
                        store.selectTheme(theme)
                        store.applySelectedTheme()
                    }
                }
            }
        }
    }

    private var sourceFooter: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(StudioColor.violet.opacity(0.14))
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(StudioColor.violet)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text("Library sync is intentionally local")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                Text("\(store.sourceSummary.localCount) managed themes discovered · WallBuddy checked at launch · nothing copied into the repo")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioColor.textMuted)
                    .lineLimit(2)
            }
            Spacer()
            Button("Browse library") {
                store.selectSection(.library)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(StudioColor.cyan)
            .buttonStyle(.plain)
        }
        .padding(16)
        .studioPanel(radius: 16, fill: Color.white.opacity(0.045))
    }

    private var canvasBackground: some View {
        ZStack {
            StudioColor.ink
            LinearGradient(colors: [StudioColor.cyan.opacity(0.035), .clear, StudioColor.violet.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func sectionTitle(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(StudioColor.text)
            Text(detail)
                .font(.system(size: 11, weight: .medium))
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
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(StudioColor.textFaint)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StudioColor.textMuted)
        }
    }
}

private struct FeaturedThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    ThemeArtworkView(theme: theme)
                        .frame(width: 196, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(StudioColor.cyan, StudioColor.ink)
                            .padding(9)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StudioColor.text)
                        .lineLimit(1)
                    Text(theme.category)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(StudioColor.textFaint)
                }
            }
            .padding(10)
            .frame(width: 216, alignment: .leading)
            .background(isSelected ? StudioColor.cyan.opacity(0.10) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isSelected ? StudioColor.cyan.opacity(0.48) : StudioColor.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct QuickSwitchCard: View {
    let theme: Theme
    let isActive: Bool
    let isSelected: Bool
    let select: () -> Void
    let apply: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: select) {
                ThemeArtworkView(theme: theme)
                    .frame(width: 49, height: 49)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioColor.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    ThemeSwatch(theme: theme, size: 13)
                    Text(isActive ? "Active in Codex" : theme.category)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isActive ? .green : StudioColor.textFaint)
                }
            }
            Spacer()
            Button(action: apply) {
                Image(systemName: isActive ? "checkmark" : "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? .green : (isSelected ? StudioColor.cyan : StudioColor.textMuted))
                    .frame(width: 27, height: 27)
                    .background(Color.white.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Apply \(theme.name)")
        }
        .padding(11)
        .studioPanel(radius: 15, fill: isSelected ? StudioColor.cyan.opacity(0.075) : Color.white.opacity(0.035))
    }
}
