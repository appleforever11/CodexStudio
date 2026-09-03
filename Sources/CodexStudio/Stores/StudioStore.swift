import AppKit
import Foundation
import SwiftUI

@MainActor
final class StudioStore: ObservableObject {
    @Published var section: StudioSection = .canvas
    @Published var themes: [Theme] = []
    @Published var selectedThemeID: String?
    @Published var themeFilter: ThemeFilter = .all
    @Published var themeSortOrder: ThemeSortOrder
    @Published var themeLayout: ThemeLayout
    @Published var selectedThemeCategory = "All"
    @Published var searchText = ""
    @Published var previewMode: PreviewMode = .home
    @Published var selectedSurface: PreviewSurface = .composer
    @Published var inspectorEnabled = true
    @Published var runtime = RuntimeStatus.unknown
    @Published var isLoading = true
    @Published var isApplying = false
    @Published var isRefreshingRuntime = false
    @Published var isOpeningCodex = false
    @Published private(set) var libraryError: String?
    @Published private(set) var lastLibraryScanDate: Date?
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
    private var bootstrapInFlight = false
    private var bootstrapGeneration = UUID()
    private var runtimeRefreshGeneration = UUID()
    private var applyGeneration = UUID()
    private var noticeToken = UUID()

    init() {
        motionEnabled = defaults.object(forKey: Keys.motionEnabled) as? Bool ?? true
        selectedThemeID = defaults.string(forKey: Keys.selectedThemeID)
        themeSortOrder = ThemeSortOrder(rawValue: defaults.string(forKey: Keys.themeSortOrder) ?? "") ?? .featured
        themeLayout = ThemeLayout(rawValue: defaults.string(forKey: Keys.themeLayout) ?? "") ?? .grid
    }

    var selectedTheme: Theme? {
        guard let selectedThemeID else { return themes.first }
        return themes.first(where: { $0.id == selectedThemeID }) ?? themes.first
    }

    var filteredThemes: [Theme] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = themes.filter { theme in
            let passesFilter: Bool
            switch themeFilter {
            case .all: passesFilter = true
            case .curated: passesFilter = theme.isCurated
            case .local: passesFilter = theme.isInstalled
            case .favorites: passesFilter = theme.isFavorite
            }
            guard passesFilter else { return false }
            guard selectedThemeCategory == "All" || theme.category == selectedThemeCategory else { return false }
            guard !query.isEmpty else { return true }
            return [theme.name, theme.author, theme.category, theme.collection, theme.description]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
        switch themeSortOrder {
        case .featured:
            return filtered.sorted(by: isFeaturedBefore)
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .category:
            return filtered.sorted {
                if $0.category != $1.category {
                    return $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .platformRelease:
            return filtered.sorted(by: isPlatformReleaseBefore)
        }
    }

    var themeCategories: [String] {
        let visibleSource = themes.filter { theme in
            switch themeFilter {
            case .all: true
            case .curated: theme.isCurated
            case .local: theme.isInstalled
            case .favorites: theme.isFavorite
            }
        }
        let categories = Set(visibleSource.map(\.category).filter { !$0.isEmpty })
        return ["All"] + categories.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var featuredThemes: [Theme] {
        let curated = themes.filter(\.isCurated)
        let candidates = curated.isEmpty ? themes.filter(\.isInstalled) : curated
        return candidates.sorted(by: isFeaturedBefore).prefix(8).map { $0 }
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

    var favoriteCount: Int {
        themes.reduce(into: 0) { count, theme in
            if theme.isFavorite { count += 1 }
        }
    }

    var connectionColor: Color {
        switch runtime.connection {
        case .connected: .green
        case .offline: .orange
        case .unavailable: StudioColor.textFaint
        }
    }

    private func isFeaturedBefore(_ lhs: Theme, _ rhs: Theme) -> Bool {
        if lhs.isCurated != rhs.isCurated { return lhs.isCurated }
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func isPlatformReleaseBefore(_ lhs: Theme, _ rhs: Theme) -> Bool {
        switch (lhs.platformRelease, rhs.platformRelease) {
        case let (left?, right?):
            if left.platform.sortIndex != right.platform.sortIndex {
                return left.platform.sortIndex < right.platform.sortIndex
            }
            if left.versionComponents != right.versionComponents {
                return left.versionComponents.lexicographicallyPrecedes(right.versionComponents)
            }
            if left.versionLabel != right.versionLabel {
                return left.versionLabel.localizedCaseInsensitiveCompare(right.versionLabel) == .orderedAscending
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return isFeaturedBefore(lhs, rhs)
        }
    }

    func bootstrap(force: Bool = false) async {
        guard !didBootstrap || force else { return }
        guard !bootstrapInFlight || force else { return }

        let generation = UUID()
        bootstrapGeneration = generation
        bootstrapInFlight = true
        isLoading = true
        libraryError = nil
        defer {
            if generation == bootstrapGeneration {
                bootstrapInFlight = false
                isLoading = false
            }
        }

        let catalog: ThemeLibraryResult = await Task.detached(priority: .userInitiated) {
            ThemeLibraryService.loadSynchronously()
        }.value
        guard generation == bootstrapGeneration else { return }

        let status = await runtimeClient.status()
        guard generation == bootstrapGeneration else { return }

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
        lastLibraryScanDate = Date()
        libraryError = hydratedThemes.isEmpty
            ? "No readable theme packs were found. Re-scan the local sources or import a theme folder."
            : nil

        let preferred = defaults.string(forKey: Keys.selectedThemeID)
        selectedThemeID = preferred.flatMap { id in hydratedThemes.contains(where: { $0.id == id }) ? id : nil }
            ?? status.activeThemeID.flatMap { id in hydratedThemes.contains(where: { $0.id == id }) ? id : nil }
            ?? hydratedThemes.first(where: \.isCurated)?.id
            ?? hydratedThemes.first?.id
        if let selectedTheme { resetEditorControls(for: selectedTheme) }

        didBootstrap = true
    }

    func monitorRuntime() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            refreshRuntime()
        }
    }

    func selectSection(_ nextSection: StudioSection) {
        section = nextSection
    }

    func selectThemes(filter: ThemeFilter = .all) {
        section = .themes
        themeFilter = filter
        selectedThemeCategory = "All"
    }

    func selectFavorites() {
        selectThemes(filter: .favorites)
    }

    func setThemeSortOrder(_ order: ThemeSortOrder) {
        themeSortOrder = order
        defaults.set(order.rawValue, forKey: Keys.themeSortOrder)
    }

    func setThemeLayout(_ layout: ThemeLayout) {
        themeLayout = layout
        defaults.set(layout.rawValue, forKey: Keys.themeLayout)
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
        showNotice(
            themes[index].isFavorite
                ? themes[index].name + " added to Favorites."
                : themes[index].name + " removed from Favorites."
        )
    }

    func applySelectedTheme() {
        guard !isApplying, let selectedTheme else { return }
        let generation = UUID()
        applyGeneration = generation
        let requestedThemeID = selectedTheme.id
        isApplying = true
        runtime.message = "Applying \(selectedTheme.name)…"
        showNotice("Applying \(selectedTheme.name)…")

        Task { [weak self] in
            guard let self else { return }
            let result = await runtimeClient.apply(themeID: requestedThemeID)
            guard generation == applyGeneration else { return }
            isApplying = false
            runtime = result.runtime
            showNotice(result.message)
        }
    }

    func refreshRuntime() {
        guard !isRefreshingRuntime else { return }
        let generation = UUID()
        runtimeRefreshGeneration = generation
        isRefreshingRuntime = true
        Task { [weak self] in
            guard let self else { return }
            let status = await runtimeClient.status()
            guard generation == runtimeRefreshGeneration else { return }
            runtime = status
            isRefreshingRuntime = false
        }
    }

    func openRuntimeLog() {
        guard let path = runtime.diagnosticLogPath else {
            showNotice("The recovery log is not available yet.")
            return
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            showNotice("No recovery attempts have been recorded yet.")
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openCodex() {
        guard !isOpeningCodex else { return }
        isOpeningCodex = true
        showNotice("Preparing themed Codex…")
        Task { [weak self] in
            guard let self else { return }
            _ = await Task.detached(priority: .userInitiated) {
                DockDoorIntegrationService.repairIfNeeded()
            }.value

            let appURL = ThemeLibraryService.installedDockDoorLauncherURL
                ?? URL(fileURLWithPath: "/Applications/ChatGPT.app")
            let opened = NSWorkspace.shared.open(appURL)
            isOpeningCodex = false
            if opened {
                showNotice("Opened themed Codex.")
            } else {
                showNotice("The themed Codex launcher could not be opened. Check that Codex is installed.")
            }
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
        static let themeSortOrder = "CodexStudio.themeSortOrder"
        static let themeLayout = "CodexStudio.themeLayout"
    }
}
