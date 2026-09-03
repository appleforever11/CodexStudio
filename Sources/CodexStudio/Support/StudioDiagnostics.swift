import Foundation

/// A deliberately small, privacy-conscious snapshot that can be copied when
/// a runtime or library issue needs to be reported. It excludes prompts,
/// artwork bytes, and credentials.
struct StudioDiagnosticsSnapshot: Sendable {
    let generatedAt: Date
    let appVersion: String
    let buildNumber: String
    let operatingSystem: String
    let themeCount: Int
    let installedThemeCount: Int
    let curatedThemeCount: Int
    let favoriteCount: Int
    let recentThemeCount: Int
    let selectedThemeName: String?
    let selectedThemeID: String?
    let runtime: RuntimeStatus
    let runtimePhase: RuntimePhase
    let lastLibraryScanDate: Date?

    init(
        generatedAt: Date = Date(),
        appVersion: String? = nil,
        buildNumber: String? = nil,
        operatingSystem: String = ProcessInfo.processInfo.operatingSystemVersionString,
        themeCount: Int,
        installedThemeCount: Int,
        curatedThemeCount: Int,
        favoriteCount: Int,
        recentThemeCount: Int,
        selectedThemeName: String?,
        selectedThemeID: String?,
        runtime: RuntimeStatus,
        runtimePhase: RuntimePhase,
        lastLibraryScanDate: Date?
    ) {
        self.generatedAt = generatedAt
        self.appVersion = appVersion
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Development"
        self.buildNumber = buildNumber
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "Unbundled"
        self.operatingSystem = operatingSystem
        self.themeCount = themeCount
        self.installedThemeCount = installedThemeCount
        self.curatedThemeCount = curatedThemeCount
        self.favoriteCount = favoriteCount
        self.recentThemeCount = recentThemeCount
        self.selectedThemeName = selectedThemeName
        self.selectedThemeID = selectedThemeID
        self.runtime = runtime
        self.runtimePhase = runtimePhase
        self.lastLibraryScanDate = lastLibraryScanDate
    }

    var text: String {
        let formatter = ISO8601DateFormatter()
        let lastScan = lastLibraryScanDate.map(formatter.string(from:)) ?? "Never"
        let lastVerification = runtime.lastVerifiedAt ?? "Never"
        let activeTheme = runtime.activeThemeName ?? "None"
        let selectedTheme = selectedThemeName.map { name in
            selectedThemeID.map { "\(name) [\($0)]" } ?? name
        } ?? "None"
        let diagnosticLog = redactedPath(runtime.diagnosticLogPath)

        return [
            "Codex Studio diagnostics",
            "Generated: \(formatter.string(from: generatedAt))",
            "App: \(appVersion) (\(buildNumber))",
            "macOS: \(operatingSystem)",
            "Catalog: \(themeCount) total, \(installedThemeCount) installed, \(curatedThemeCount) curated",
            "Favorites: \(favoriteCount) · Recent: \(recentThemeCount)",
            "Selected theme: \(selectedTheme)",
            "Runtime: \(runtime.connection.label) · \(runtimePhase.label)",
            "Active theme: \(activeTheme)",
            "Codex version: \(runtime.codexVersion ?? "Not reported")",
            "Loopback port: \(runtime.port.map(String.init) ?? "Not reported")",
            "Relaunch recovery: \(runtime.persistenceEnabled ? "Armed" : "Not armed")",
            "Last runtime verification: \(lastVerification)",
            "Last library scan: \(lastScan)",
            "Recovery log: \(diagnosticLog)"
        ].joined(separator: "\n")
    }

    private func redactedPath(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return "Not available" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard path.hasPrefix(home) else { return path }
        return "~" + String(path.dropFirst(home.count))
    }
}
