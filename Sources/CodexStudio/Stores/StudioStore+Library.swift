import AppKit
import SwiftUI
import OSLog

extension StudioStore {
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

    func installCatalog(_ catalog: ThemeLibraryResult, status: RuntimeStatus, scannedAt: Date?) {
        let previousSelection = selectedThemeID
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
        // A catalog refresh must not discard an in-progress edit of the same theme.
        if previousSelection != selectedThemeID, let selectedTheme {
            resetEditorControls(for: selectedTheme)
        }
    }

}
