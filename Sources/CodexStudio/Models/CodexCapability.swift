import Foundation

enum CodexCapabilityHealth: String, Sendable {
    case ready
    case partial
    case needsAttention
    case unavailable

    var label: String {
        switch self {
        case .ready: "Ready"
        case .partial: "Partially verified"
        case .needsAttention: "Needs attention"
        case .unavailable: "Unavailable"
        }
    }

    var symbol: String {
        switch self {
        case .ready: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .needsAttention: "exclamationmark.triangle.fill"
        case .unavailable: "questionmark.circle"
        }
    }
}

struct CodexTargetSummary: Sendable, Equatable {
    let total: Int
    let codexPageCount: Int
    let excludedSurfaceCount: Int
    let webviewCount: Int
    let externalPageCount: Int
    let unsupportedCount: Int

    static let unknown = CodexTargetSummary(
        total: 0,
        codexPageCount: 0,
        excludedSurfaceCount: 0,
        webviewCount: 0,
        externalPageCount: 0,
        unsupportedCount: 0
    )

    var displayValue: String {
        guard total > 0 else { return "No renderer targets reported" }
        let pageLabel = codexPageCount == 1 ? "app page" : "app pages"
        let webviewLabel = webviewCount == 1 ? "embedded webview" : "embedded webviews"
        return "\(codexPageCount) \(pageLabel) · \(webviewCount) \(webviewLabel)"
    }
}

struct CodexCapabilityFeature: Identifiable, Sendable, Equatable {
    let id: String
    let stage: String
    let enabled: Bool

    var label: String {
        Self.displayNames[id] ?? id
            .split(separator: "_")
            .map(String.init)
            .joined(separator: " ")
            .capitalized
    }

    var availabilityLabel: String {
        if enabled { return "Available" }
        return stage.isEmpty ? "Not enabled" : stage.capitalized
    }

    private static let displayNames: [String: String] = [
        "apps": "Apps",
        "app_server": "App-server",
        "browser_use": "Browser use",
        "code_mode_host": "Code mode host",
        "computer_use": "Computer use",
        "in_app_browser": "In-app browser",
        "memories": "Memories",
        "multi_agent": "Multi-agent",
        "plugins": "Plugins",
        "skills": "Skills",
        "unified_exec": "Unified exec",
        "view_image": "View image",
        "workspace_dependencies": "Workspace dependencies",
    ]
}

struct CodexCapabilitySnapshot: Sendable, Equatable {
    let checkedAt: Date?
    let health: CodexCapabilityHealth
    let message: String
    let bundleIdentifier: String?
    let bundlePath: String?
    let appVersion: String?
    let appBuild: String?
    let executableName: String?
    let processID: Int32?
    let isRunning: Bool
    let installedRuntimeVersion: String?
    let recordedRuntimeVersion: String?
    let bundledRuntimeVersion: String?
    let port: Int?
    let browserVersion: String?
    let cdpProtocol: String?
    let targets: CodexTargetSummary
    let bundledNodeVersion: String?
    let codexCLI: String?
    let appServerAvailable: Bool
    let features: [CodexCapabilityFeature]

    static let unknown = CodexCapabilitySnapshot(
        checkedAt: nil,
        health: .unavailable,
        message: "Capability inspection has not run yet.",
        bundleIdentifier: nil,
        bundlePath: nil,
        appVersion: nil,
        appBuild: nil,
        executableName: nil,
        processID: nil,
        isRunning: false,
        installedRuntimeVersion: nil,
        recordedRuntimeVersion: nil,
        bundledRuntimeVersion: nil,
        port: nil,
        browserVersion: nil,
        cdpProtocol: nil,
        targets: .unknown,
        bundledNodeVersion: nil,
        codexCLI: nil,
        appServerAvailable: false,
        features: []
    )

    var enabledFeatureCount: Int {
        features.filter(\.enabled).count
    }

    var featureCount: Int { features.count }

    var highlightedFeatures: [CodexCapabilityFeature] {
        let importantIDs = [
            "apps", "browser_use", "code_mode_host", "computer_use",
            "in_app_browser", "multi_agent", "plugins", "unified_exec",
        ]
        return importantIDs.map { id in
            features.first(where: { $0.id == id })
                ?? CodexCapabilityFeature(id: id, stage: "Not reported", enabled: false)
        }
    }

    func feature(named id: String) -> CodexCapabilityFeature? {
        features.first(where: { $0.id == id })
    }
}
