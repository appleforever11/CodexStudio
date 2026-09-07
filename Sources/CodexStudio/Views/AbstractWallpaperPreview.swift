import SwiftUI

struct AbstractWallpaperPreview: View {
    let item: AbstractWallpaper
    let onImport: (MoeDownloadOption) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("moePreferredQuality") private var preferredQuality = "original"
    @State private var options: [MoeDownloadOption] = []
    @State private var loading = true
    @State private var error: String?
    @State private var playing = false
    @State private var playbackStatus = "Loading site preview…"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name).font(.title2.bold())
                    Text("MoeWalls Abstract · Download only what you choose")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").padding(4) }
                    .modifier(MoeGlassControl()).help("Close preview").keyboardShortcut(.cancelAction)
            }
            Color.black.aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if playing, let preview = options.first(where: { !$0.original }) {
                        MoeAnimationPreview(url: preview.url) { playbackStatus = $0 }
                    } else {
                        AsyncImage(url: item.previewImageURL) { phase in
                            if let image = phase.image { image.resizable().scaledToFit() }
                            else if phase.error != nil { ContentUnavailableView("Preview unavailable", systemImage: "photo") }
                            else { ProgressView().tint(.white) }
                        }
                    }
                }
                .overlay(alignment: .topLeading) {
                    if options.contains(where: { !$0.original }) {
                        Button {
                            playing.toggle()
                            playbackStatus = "Loading site preview…"
                        } label: {
                            Label(playing ? "Back to image" : "Preview animation", systemImage: playing ? "photo" : "play.fill")
                        }.modifier(MoeGlassControl()).padding(16)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            VStack(alignment: .leading, spacing: 12) {
                if playing { Text(playbackStatus).font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Text("Download quality").font(.headline)
                    Spacer()
                    Link("Creator & source", destination: item.url).font(.callout)
                }
                if loading { ProgressView("Checking available source resolutions…").controlSize(.small) }
                if let error { Text(error).foregroundStyle(.secondary).font(.callout) }
                StudioGlassGroup {
                    HStack(spacing: 12) {
                        ForEach(options) { option in
                            Button { preferredQuality = option.id } label: {
                                Label(option.label, systemImage: preferredQuality == option.id ? "checkmark.circle.fill" : "circle")
                            }
                            .modifier(MoeGlassControl(prominent: preferredQuality == option.id))
                            .accessibilityValue(preferredQuality == option.id ? "Selected" : "Not selected")
                        }
                        Spacer(minLength: 12)
                        Button {
                            if let option = options.first(where: { $0.id == preferredQuality }) { onImport(option) }
                        } label: { Label("Download & import", systemImage: "arrow.down.circle") }
                            .modifier(MoeGlassControl(prominent: true))
                            .disabled(loading || options.isEmpty)
                    }
                }
                Text("Original keeps the source resolution in a short loop at up to 15 fps. Preview imports a smaller 960px loop. The site animation preview can be lower quality than the original download.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24).frame(width: 840)
        .task(id: item.id) {
            do {
                options = try await AbstractWallpaperService.options(for: item)
                if !options.contains(where: { $0.id == preferredQuality }) { preferredQuality = options[0].id }
            } catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

private struct MoeGlassControl: ViewModifier {
    var prominent = false
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { content.buttonStyle(.glassProminent).controlSize(.large) }
            else { content.buttonStyle(.glass).controlSize(.large) }
        } else {
            if prominent { content.buttonStyle(.borderedProminent).controlSize(.large) }
            else { content.buttonStyle(.bordered).controlSize(.large) }
        }
    }
}
