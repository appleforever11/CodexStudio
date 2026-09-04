import SwiftUI

/// Shared by Canvas and the catalog. Only the finite frame participates in
/// layout; artwork and the ambient halo are decorative background layers.
struct ThemeHero: View {
    @EnvironmentObject private var store: StudioStore
    let theme: Theme
    var height: CGFloat = 440
    var compact = false
    @State private var showingArtwork = false

    private var isActive: Bool { store.runtime.activeThemeID == theme.id }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background { ThemeAmbientGlow(theme: theme) }
            .overlay {
                GeometryReader { geometry in
                    ThemeArtworkView(theme: theme, showOverlay: false, maxPixelSize: 2400, preferOriginal: true)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay {
                            LinearGradient(colors: [.black.opacity(0.02), .clear, .black.opacity(0.76)],
                                startPoint: .top, endPoint: .bottom)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 26))
            }
            .overlay(alignment: .top) { topControls.padding(22) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: compact ? 12 : 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(theme.platformRelease?.displayName ?? theme.category)
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                        Text(theme.name)
                            .font(.system(size: compact ? 30 : 42, weight: .bold))
                            .foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.75)
                            .accessibilityAddTraits(.isHeader)
                        if !compact {
                            Text(theme.isInstalled ? "Ready in your local library. Preview freely, apply when it feels right."
                                : "Explore this artwork before adding it to your workspace.")
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.78)).lineLimit(2)
                        }
                    }
                    StudioGlassGroup {
                        HStack(spacing: 10) {
                            StudioActionButton(title: store.isApplying ? "Applying…" : (isActive ? "Applied to Codex" : "Apply to Codex"),
                                symbol: isActive ? "checkmark" : "sparkles", prominent: true, busy: store.isApplying) {
                                    store.selectTheme(theme)
                                    store.applySelectedTheme()
                                }
                                .disabled(!store.canApply || !theme.isInstalled || isActive)
                            StudioActionButton(title: "Customize", symbol: "slider.horizontal.3") {
                                store.selectTheme(theme, openEditor: true)
                            }
                        }
                    }
                    .environment(\.colorScheme, .dark)
                }
                .padding(compact ? 24 : 30)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .sheet(isPresented: $showingArtwork) { ThemeArtworkDetail(theme: theme) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("theme.hero")
    }

    private var topControls: some View {
        HStack(alignment: .top) {
            Label(isActive ? "Active in Codex" : (store.selectedThemeID == theme.id ? "On your canvas" : "Artwork preview"),
                systemImage: isActive ? "checkmark.circle.fill" : "viewfinder")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).frame(height: 32)
                .studioGlass(radius: 18)
            Spacer()
            StudioGlassGroup {
                HStack(spacing: 10) {
                    ThemeFavoriteButton(theme: theme)
                    Button { showingArtwork = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(StudioPressableButtonStyle()).studioGlass(radius: 18)
                    .help("View full artwork").accessibilityLabel("View full artwork")
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

struct ThemeAmbientGlow: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let theme: Theme

    var body: some View {
        GeometryReader { geometry in
            if !reduceTransparency {
                ThemeArtworkView(theme: theme, showOverlay: false, maxPixelSize: 160)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .scaleEffect(x: 1.035, y: 1.13)
                    .blur(radius: 35)
                    .saturation(1.3)
                    .opacity(0.68)
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct ThemeArtworkDetail: View {
    @Environment(\.dismiss) private var dismiss
    let theme: Theme
    @State private var image: NSImage?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.name).font(.title3.bold())
                    Text(theme.platformRelease?.displayName ?? theme.category).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
            GeometryReader { geometry in
                ZStack {
                    Color.black
                    if let image {
                        Image(nsImage: image).resizable().scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if isLoading { ProgressView() }
                    else {
                        ContentUnavailableView("Artwork unavailable", systemImage: "photo",
                            description: Text("The local image could not be read. Close this preview and re-scan the library in Settings."))
                    }
                }
            }
            HStack {
                Text(theme.shortDescription).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                Spacer()
                if let url = theme.sourceURL.flatMap(URL.init(string:)), ["https", "http"].contains(url.scheme ?? "") {
                    Link("Artwork source", destination: url).font(.caption)
                }
            }.padding(20)
        }
        .frame(minWidth: 800, idealWidth: 1000, minHeight: 550, idealHeight: 680)
        .task(id: theme.id) {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }
            guard let path = theme.imagePath ?? theme.previewPath else { return }
            let data = await ThemeImageCache.shared.data(atPath: path, maxPixelSize: 2800)
            guard !Task.isCancelled else { return }
            image = data.flatMap(NSImage.init(data:))
        }
    }
}
