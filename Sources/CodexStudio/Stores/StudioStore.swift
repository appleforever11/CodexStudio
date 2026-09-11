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
    @Published var recentThemeIDs: [String] { didSet { updateCatalog() } }
    @Published var filteredThemes: [Theme] = []
    @Published var availableReleases: [ThemePlatformRelease] = []
    @Published var previewMode: PreviewMode = .home
    @Published var selectedSurface: PreviewSurface = .composer
    @Published var inspectorEnabled = true
    @Published var runtime = RuntimeStatus.unknown
    @Published var capabilities = CodexCapabilitySnapshot.unknown
    @Published var isLoading = true
    @Published var isApplying = false
    @Published var isRefreshingRuntime = false
    @Published var isInspectingCapabilities = false
    @Published var isOpeningCodex = false
    @Published var isScanningLibrary = false
    @Published var runtimePhase: RuntimePhase = .idle
    @Published var libraryError: String?
    @Published var lastLibraryScanDate: Date?
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

    let runtimeClient = CodexRuntimeClient()
    let defaults = UserDefaults.standard
    var didBootstrap = false
    var bootstrapInFlight = false
    var bootstrapGeneration = UUID()
    var runtimeRefreshGeneration = UUID()
    var capabilityGeneration = UUID()
    var applyGeneration = UUID()
    var noticeToken = UUID()
    var runtimeCheckTask: Task<Void, Never>?
    var capabilityTask: Task<Void, Never>?
    var applyTask: Task<Void, Never>?
    let logger = Logger(subsystem: "local.kevinhowe.CodexStudio", category: "Studio")
    let capabilityService = CodexCapabilityService()

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
            lastLibraryScanDate: lastLibraryScanDate,
            capabilities: capabilities
        )
    }

    var connectionColor: Color {
        switch runtime.connection {
        case .connected: .green
        case .offline: .orange
        case .unavailable: StudioColor.textFaint
        }
    }

    func isFeaturedBefore(_ lhs: Theme, _ rhs: Theme) -> Bool {
        if lhs.isCurated != rhs.isCurated { return lhs.isCurated }
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    func monitorRuntime() async {
        while !Task.isCancelled {
            let interval: Duration = runtime.connection == .connected ? .seconds(12) : .seconds(5)
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            refreshRuntime()
        }
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

    enum Keys {
        static let selectedThemeID = "CodexStudio.selectedThemeID"
        static let favoriteIDs = "CodexStudio.favoriteIDs"
        static let recentThemeIDs = "CodexStudio.recentThemeIDs"
        static let motionEnabled = "CodexStudio.motionEnabled"
        static let themeSortOrder = "CodexStudio.themeSortOrder"
        static let themeLayout = "CodexStudio.themeLayout"
    }
}
