import AppKit
import Foundation
import SwiftUI

@MainActor
final class StudioStore: ObservableObject {
    @Published var section: StudioSection = .canvas
    @Published var themes: [Theme] = []
    @Published var selectedThemeID: String?
    @Published var themeFilter: ThemeFilter = .all
    @Published var searchText = ""
    @Published var previewMode: PreviewMode = .home
    @Published var selectedSurface: PreviewSurface = .composer
    @Published var inspectorEnabled = true
    @Published var runtime = RuntimeStatus.unknown
    @Published var isLoading = true
    @Published var isApplying = false
    @Published var notice: String?
    @Published var sourceSummary = ThemeLibraryResult(
        themes: [],
        curatedCount: 0,
        localCount: 0,
        wallBuddyCount: 0,
        managedPath: ThemeLibraryService.managedThemesDirectory.path,
        wallBuddyPath: ThemeLibraryService.wallBuddyBundle.path,
        message: "Preparing the studio…"
    )

    @Published var draftAccent: Color = StudioColor.cyan
    @Published var draftOpacity: Double = 0.82
    @Published var draftBlur: Double = 18
    @Published var draftRadius: Double = 22
    @Published var motionEnabled: Bool

    private let runtimeClient = CodexRuntimeClient()
    private let defaults = UserDefaults.standard
    private var didBootstrap = false
    private var noticeToken = UUID()

    init() {
        motionEnabled = defaults.object(forKey: Keys.motionEnabled) as? Bool ?? true
        selectedThemeID = defaults.string(forKey: Keys.selectedThemeID)
    }

    var selectedTheme: Theme? {
        guard let selectedThemeID else { return themes.first }
        return themes.first(where: { $0.id == selectedThemeID }) ?? themes.first
    }

    var filteredThemes: [Theme] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return themes.filter { theme in
            let passesFilter: Bool
            switch themeFilter {
            case .all: passesFilter = true
            case .curated: passesFilter = theme.isCurated
            case .local: passesFilter = theme.origin == .local || theme.origin == .wallBuddy
            case .favorites: passesFilter = theme.isFavorite
            }
            guard passesFilter else { return false }
            guard !query.isEmpty else { return true }
            return [theme.name, theme.author, theme.category, theme.description]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    var featuredThemes: [Theme] {
        themes.filter(\.isCurated).prefix(8).map { $0 }
    }

    var quickSwitchThemes: [Theme] {
        let installed = themes.filter(\.isInstalled)
        if installed.count <= 6 { return installed }
        var result = Array(installed.prefix(5))
        if let selectedTheme, !result.contains(where: { $0.id == selectedTheme.id }) {
            result.append(selectedTheme)
        }
        return result
    }

    var connectionColor: Color {
        switch runtime.connection {
        case .connected: .green
        case .offline: .orange
        case .unavailable: StudioColor.textFaint
        }
    }

    func bootstrap(force: Bool = false) async {
        guard !didBootstrap || force else { return }
        didBootstrap = true
        isLoading = true

        let catalog: ThemeLibraryResult = await Task.detached(priority: .userInitiated) {
            ThemeLibraryService.loadSynchronously()
        }.value
        let status = await runtimeClient.status()

        var hydratedThemes = catalog.themes
        let favoriteIDs = Set(defaults.stringArray(forKey: Keys.favoriteIDs) ?? [])
        for index in hydratedThemes.indices {
            hydratedThemes[index].isFavorite = favoriteIDs.contains(hydratedThemes[index].id)
        }

        themes = hydratedThemes
        sourceSummary = ThemeLibraryResult(
            themes: hydratedThemes,
            curatedCount: catalog.curatedCount,
            localCount: catalog.localCount,
            wallBuddyCount: catalog.wallBuddyCount,
            managedPath: catalog.managedPath,
            wallBuddyPath: catalog.wallBuddyPath,
            message: catalog.message
        )
        runtime = status

        let preferred = defaults.string(forKey: Keys.selectedThemeID)
        selectedThemeID = preferred.flatMap { id in hydratedThemes.contains(where: { $0.id == id }) ? id : nil }
            ?? status.activeThemeID.flatMap { id in hydratedThemes.contains(where: { $0.id == id }) ? id : nil }
            ?? hydratedThemes.first(where: \.isCurated)?.id
            ?? hydratedThemes.first?.id
        if let selectedTheme { resetEditorControls(for: selectedTheme) }

        isLoading = false
    }

    func selectSection(_ nextSection: StudioSection) {
        section = nextSection
    }

    func selectTheme(_ theme: Theme, openEditor: Bool = false) {
        selectedThemeID = theme.id
        defaults.set(theme.id, forKey: Keys.selectedThemeID)
        resetEditorControls(for: theme)
        if openEditor { section = .canvas }
    }

    func toggleFavorite(_ theme: Theme) {
        guard let index = themes.firstIndex(where: { $0.id == theme.id }) else { return }
        themes[index].isFavorite.toggle()
        let ids = themes.filter(\.isFavorite).map(\.id)
        defaults.set(ids, forKey: Keys.favoriteIDs)
    }

    func applySelectedTheme() {
        guard !isApplying, let selectedTheme else { return }
        isApplying = true
        runtime.message = "Applying \(selectedTheme.name)…"
        showNotice("Applying \(selectedTheme.name)…")

        Task { [weak self] in
            guard let self else { return }
            let result = await runtimeClient.apply(themeID: selectedTheme.id)
            isApplying = false
            runtime = result.runtime
            if result.verified {
                selectedThemeID = selectedTheme.id
                defaults.set(selectedTheme.id, forKey: Keys.selectedThemeID)
            }
            showNotice(result.message)
        }
    }

    func refreshRuntime() {
        Task { [weak self] in
            guard let self else { return }
            runtime = await runtimeClient.status()
        }
    }

    func openCodex() {
        _ = DockDoorIntegrationService.repairIfNeeded()
        let appURL = ThemeLibraryService.installedDockDoorLauncherURL
            ?? URL(fileURLWithPath: "/Applications/ChatGPT.app")
        if !NSWorkspace.shared.open(appURL) {
            showNotice("The themed Codex launcher could not be opened. Check that Codex is installed.")
        } else {
            showNotice("Opened themed Codex.")
        }
    }

    func importThemeFolder() {
        let panel = NSOpenPanel()
        panel.title = "Import Codex theme folder"
        panel.message = "Choose an extracted folder containing theme.json and its image."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        showNotice("Validating theme package…")
        Task { [weak self] in
            do {
                let message = try await Task.detached(priority: .userInitiated) {
                    try ThemeLibraryService.importTheme(from: url)
                }.value
                guard let self else { return }
                await bootstrap(force: true)
                showNotice(message)
            } catch {
                self?.showNotice(error.localizedDescription)
            }
        }
    }

    func revealManagedThemes() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: sourceSummary.managedPath)
    }

    func restoreOriginal() {
        guard !isApplying else { return }
        isApplying = true
        showNotice("Restoring the original Codex appearance…")
        Task { [weak self] in
            guard let self else { return }
            let result = await runtimeClient.restoreOriginal()
            isApplying = false
            runtime = result.runtime
            showNotice(result.message)
        }
    }

    func saveEditorDraft() {
        guard let selectedTheme else { return }
        let title = "\(selectedTheme.name) Variation"
        let safeName = title.lowercased().map { character in
            character.isLetter || character.isNumber ? String(character) : "-"
        }.joined().split(separator: "-").joined(separator: "-")
        let directory = ThemeLibraryService.homeDirectory
            .appendingPathComponent("Library/Application Support/CodexStudio/Drafts", isDirectory: true)
        let url = directory.appendingPathComponent("\(safeName)-\(Int(Date().timeIntervalSince1970)).json")
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "kind": "codex-studio-draft",
            "name": title,
            "referenceThemeID": selectedTheme.id,
            "accent": draftAccent.hexDescription,
            "panelOpacity": draftOpacity,
            "backdropBlur": draftBlur,
            "cornerRadius": draftRadius,
            "previewMode": previewMode.rawValue,
            "selectedSurface": selectedSurface.rawValue,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            showNotice("Saved \(title) to your Codex Studio drafts.")
        } catch {
            showNotice("Could not save the draft: \(error.localizedDescription)")
        }
    }

    func setMotionEnabled(_ enabled: Bool) {
        motionEnabled = enabled
        defaults.set(enabled, forKey: Keys.motionEnabled)
    }

    func resetEditorControls(for theme: Theme) {
        draftAccent = Color(hex: theme.palette.accent)
        draftOpacity = theme.id.contains("obsidian") ? 0.94 : 0.78
        draftBlur = theme.id.contains("obsidian") ? 4 : 18
        draftRadius = theme.id.contains("obsidian") ? 8 : 22
    }

    func showNotice(_ message: String) {
        noticeToken = UUID()
        let token = noticeToken
        notice = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.noticeToken == token else { return }
            notice = nil
        }
    }

    private enum Keys {
        static let selectedThemeID = "CodexStudio.selectedThemeID"
        static let favoriteIDs = "CodexStudio.favoriteIDs"
        static let motionEnabled = "CodexStudio.motionEnabled"
    }
}
