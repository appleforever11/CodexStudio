import AppKit
import Foundation
import OSLog
import SwiftUI

@MainActor
final class StudioStore: ObservableObject {
    @Published var section: StudioSection = .canvas
    @Published var themes: [Theme] = [] { didSet { updateCatalog() } }
    @Published var selectedThemeID: String?
    @Published var themeFilter: ThemeFilter = .all { didSet { updateCatalog() } }
    @Published var themeSortOrder: ThemeSortOrder { didSet { updateCatalog() } }
    @Published var themeLayout: ThemeLayout
    @Published var selectedThemeCategory = "All" {
        didSet { selectedReleaseID = nil; updateCatalog() }
    }
    @Published var selectedReleaseID: String? { didSet { updateCatalog() } }
    @Published var searchText = "" { didSet { updateCatalog() } }
    @Published private(set) var recentThemeIDs: [String] { didSet { updateCatalog() } }
    @Published private(set) var filteredThemes: [Theme] = []
    @Published private(set) var availableReleases: [ThemePlatformRelease] = []
    @Published var previewMode: PreviewMode = .home
    @Published var selectedSurface: PreviewSurface = .composer
    @Published var inspectorEnabled = true
    @Published var runtime = RuntimeStatus.unknown
    @Published var isLoading = true
    @Published var isApplying = false
    @Published var isRefreshingRuntime = false
    @Published var isOpeningCodex = false
    @Published var isScanningLibrary = false
    @Published private(set) var runtimePhase: RuntimePhase = .idle
    @Published private(set) var libraryError: String?
    @Published private(set) var lastLibraryScanDate: Date?
    @Published var notice: String?
    @Published var sourceSummary = ThemeLibraryResult(
        themes: [],
        curatedCount: 0,
        localCount: 0,
        managedPath: ThemeLibraryService.managedThemesDirectory.path,
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
    private var runtimeCheckTask: Task<Void, Never>?
    private var applyTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "local.kevinhowe.CodexStudio", category: "Studio")

    init() {
        motionEnabled = defaults.object(forKey: Keys.motionEnabled) as? Bool ?? true
        selectedThemeID = defaults.string(forKey: Keys.selectedThemeID)
        recentThemeIDs = defaults.stringArray(forKey: Keys.recentThemeIDs) ?? []
        themeSortOrder = ThemeSortOrder(rawValue: defaults.string(forKey: Keys.themeSortOrder) ?? "") ?? .featured
        themeLayout = ThemeLayout(rawValue: defaults.string(forKey: Keys.themeLayout) ?? "") ?? .grid
    }

    var selectedTheme: Theme? {
        guard let selectedThemeID else { return themes.first }
        return themes.first(where: { $0.id == selectedThemeID }) ?? themes.first
    }

    var canApply: Bool { !isApplying && !isLoading && !isOpeningCodex }

    private func updateCatalog() {
        let query = ThemeCatalogQuery(filter: themeFilter, category: selectedThemeCategory,
            releaseID: selectedReleaseID, search: searchText, order: themeSortOrder, recentIDs: recentThemeIDs)
        filteredThemes = query.results(in: themes)
        availableReleases = query.releases(in: themes)
    }

    var themeCategories: [String] {
        let visibleSource = themes.filter { theme in
            switch themeFilter {
            case .all: true
            case .curated: theme.isCurated
            case .local: theme.isInstalled
            case .favorites: theme.isFavorite
            case .recent: recentThemeIDs.contains(theme.id)
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

    var recentThemes: [Theme] {
        recentThemeIDs.compactMap { id in themes.first(where: { $0.id == id }) }
    }

    var diagnosticsSnapshot: StudioDiagnosticsSnapshot {
        StudioDiagnosticsSnapshot(
            themeCount: themes.count,
            installedThemeCount: sourceSummary.localCount,
            curatedThemeCount: sourceSummary.curatedCount,
            favoriteCount: favoriteCount,
            recentThemeCount: recentThemes.count,
            selectedThemeName: selectedTheme?.name,
            selectedThemeID: selectedTheme?.id,
            runtime: runtime,
            runtimePhase: runtimePhase,
            lastLibraryScanDate: lastLibraryScanDate
        )
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

    func bootstrap(force: Bool = false) async {
        guard !isApplying else { return }
        guard !didBootstrap || force else { return }
        guard !bootstrapInFlight else {
            logger.debug("Skipped local catalog bootstrap because one is already running")
            return
        }

        let generation = UUID()
        bootstrapGeneration = generation
        bootstrapInFlight = true
        isLoading = true
        isScanningLibrary = true
        runtimePhase = .checking
        logger.info("Starting local catalog bootstrap")
        libraryError = nil
        defer {
            if generation == bootstrapGeneration {
                bootstrapInFlight = false
                isLoading = false
                isScanningLibrary = false
                if runtimePhase == .checking {
                    runtimePhase = themes.isEmpty ? .failed : .idle
                }
            }
        }

        let cachedCatalog = await Task.detached(priority: .utility) {
            ThemeLibraryService.loadCachedSynchronously()
        }.value
        guard generation == bootstrapGeneration else { return }

        let initialStatus = await runtimeClient.status()
        guard generation == bootstrapGeneration else { return }

        if let cachedCatalog {
            installCatalog(cachedCatalog, status: initialStatus, scannedAt: nil)
            isLoading = false
        }

        let catalog: ThemeLibraryResult = await Task.detached(priority: .userInitiated) {
            ThemeLibraryService.loadSynchronously()
        }.value
        guard generation == bootstrapGeneration else { return }
        let status = await runtimeClient.status()
        guard generation == bootstrapGeneration else { return }

        installCatalog(catalog, status: status, scannedAt: Date())
        runtimePhase = catalog.themes.isEmpty ? .failed : .idle
        logger.info("Local catalog ready: \(catalog.themes.count, privacy: .public) themes")
        didBootstrap = true
    }

    private func installCatalog(_ catalog: ThemeLibraryResult, status: RuntimeStatus, scannedAt: Date?) {
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
            managedPath: catalog.managedPath,
            message: catalog.message
        )
        runtime = status
        if let scannedAt {
            lastLibraryScanDate = scannedAt
        }
        libraryError = hydratedThemes.isEmpty
            ? "No readable theme packs were found. Re-scan the local library or import a theme folder."
            : nil

        let preferred = defaults.string(forKey: Keys.selectedThemeID)
        selectedThemeID = preferred.flatMap { id in hydratedThemes.contains(where: { $0.id == id }) ? id : nil }
            ?? status.activeThemeID.flatMap { id in hydratedThemes.contains(where: { $0.id == id }) ? id : nil }
            ?? hydratedThemes.first(where: \.isCurated)?.id
            ?? hydratedThemes.first?.id
        if let selectedTheme { resetEditorControls(for: selectedTheme) }
    }

    func monitorRuntime() async {
        while !Task.isCancelled {
            let interval: Duration = runtime.connection == .connected ? .seconds(12) : .seconds(5)
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            refreshRuntime()
        }
    }

    func selectSection(_ nextSection: StudioSection) {
        logger.debug("Selected section: \(nextSection.rawValue, privacy: .public)")
        section = nextSection
        if nextSection == .library {
            themeFilter = .local
            resetCatalogFilters()
        }
    }

    func selectThemes(filter: ThemeFilter = .all) {
        section = .themes
        themeFilter = filter
        resetCatalogFilters()
    }

    func resetCatalogFilters() {
        searchText = ""
        selectedThemeCategory = "All"
        selectedReleaseID = nil
    }

    func selectPlatform(_ platform: StudioPlatform) {
        selectThemes()
        selectedThemeCategory = platform.category
        setThemeSortOrder(.platformRelease)
    }

    func selectFavorites() {
        selectThemes(filter: .favorites)
    }

    func selectRecent() {
        selectThemes(filter: .recent)
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
        recordRecentTheme(theme.id)
        logger.debug("Selected theme: \(theme.id, privacy: .public)")
        resetEditorControls(for: theme)
        if openEditor { section = .editor }
    }

    private func recordRecentTheme(_ id: String) {
        recentThemeIDs.removeAll { $0 == id }
        recentThemeIDs.insert(id, at: 0)
        recentThemeIDs = Array(recentThemeIDs.prefix(8))
        defaults.set(recentThemeIDs, forKey: Keys.recentThemeIDs)
    }

    func toggleFavorite(_ theme: Theme) {
        guard let index = themes.firstIndex(where: { $0.id == theme.id }) else { return }
        themes[index].isFavorite.toggle()
        let ids = themes.filter(\.isFavorite).map(\.id)
        defaults.set(ids, forKey: Keys.favoriteIDs)
        logger.info("Favorite changed: \(theme.id, privacy: .public) -> \(self.themes[index].isFavorite, privacy: .public)")
        showNotice(
            themes[index].isFavorite
                ? themes[index].name + " added to Favorites."
                : themes[index].name + " removed from Favorites."
        )
    }

    func applySelectedTheme() {
        guard canApply, let selectedTheme else { return }
        let generation = UUID()
        applyGeneration = generation
        let requestedThemeID = selectedTheme.id
        cancelRuntimeRefresh()
        isApplying = true
        runtimePhase = .applying
        runtime.message = "Applying \(selectedTheme.name)…"
        showNotice("Applying \(selectedTheme.name)…")

        applyTask?.cancel()
        applyTask = Task { [weak self] in
            guard let self else { return }
            let result = await runtimeClient.apply(themeID: requestedThemeID)
            guard !Task.isCancelled, generation == applyGeneration else { return }
            isApplying = false
            runtime = result.runtime
            runtimePhase = result.verified ? .idle : .failed
            logger.info("Theme apply finished: \(requestedThemeID, privacy: .public), verified=\(result.verified, privacy: .public)")
            showNotice(result.message)
        }
    }

    private func cancelRuntimeRefresh() {
        runtimeRefreshGeneration = UUID()
        runtimeCheckTask?.cancel()
        runtimeCheckTask = nil
        isRefreshingRuntime = false
    }

    func refreshRuntime() {
        guard !isRefreshingRuntime, !isApplying, !isLoading else { return }
        let generation = UUID()
        runtimeRefreshGeneration = generation
        isRefreshingRuntime = true
        runtimePhase = .checking
        runtimeCheckTask?.cancel()
        logger.debug("Checking Codex runtime status")
        runtimeCheckTask = Task { [weak self] in
            guard let self else { return }
            let status = await runtimeClient.status()
            guard !Task.isCancelled, generation == runtimeRefreshGeneration else { return }
            runtime = status
            isRefreshingRuntime = false
            runtimePhase = status.connection == .unavailable ? .failed : .idle
            logger.info("Runtime check finished: \(status.connection.rawValue, privacy: .public)")
        }
    }

    func copyDiagnostics() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnosticsSnapshot.text, forType: .string)
        logger.info("Copied diagnostics summary")
        showNotice("Copied a safe diagnostics summary.")
    }

    func openSupportFolder() {
        let supportDirectory = ThemeLibraryService.managedThemesDirectory
            .deletingLastPathComponent()
        guard NSWorkspace.shared.open(supportDirectory) else {
            showNotice("The support folder could not be opened.")
            return
        }
        logger.info("Opened local support folder")
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
        guard !isOpeningCodex, !isApplying else { return }
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
        guard canApply else { return }
        cancelRuntimeRefresh()
        let generation = UUID()
        applyGeneration = generation
        isApplying = true
        runtimePhase = .recovering
        showNotice("Restoring the original Codex appearance…")
        applyTask?.cancel()
        applyTask = Task { [weak self] in
            guard let self else { return }
            let result = await runtimeClient.restoreOriginal()
            guard !Task.isCancelled, generation == applyGeneration else { return }
            isApplying = false
            runtime = result.runtime
            runtimePhase = result.verified ? .idle : .failed
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
        static let recentThemeIDs = "CodexStudio.recentThemeIDs"
        static let motionEnabled = "CodexStudio.motionEnabled"
        static let themeSortOrder = "CodexStudio.themeSortOrder"
        static let themeLayout = "CodexStudio.themeLayout"
    }
}
