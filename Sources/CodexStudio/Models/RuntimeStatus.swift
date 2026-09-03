import Foundation

enum RuntimeConnection: String, Sendable {
    case connected
    case offline
    case unavailable

    var label: String {
        switch self {
        case .connected: "Connected"
        case .offline: "Offline"
        case .unavailable: "Runtime unavailable"
        }
    }
}

enum RuntimePhase: String, Sendable {
    case idle
    case checking
    case applying
    case recovering
    case failed

    var label: String {
        switch self {
        case .idle: "Ready"
        case .checking: "Checking"
        case .applying: "Applying and verifying"
        case .recovering: "Recovering"
        case .failed: "Needs attention"
        }
    }

    var symbol: String {
        switch self {
        case .idle: "checkmark.circle"
        case .checking: "arrow.triangle.2.circlepath"
        case .applying: "bolt.horizontal.circle"
        case .recovering: "arrow.counterclockwise.circle"
        case .failed: "exclamationmark.triangle"
        }
    }
}

struct RuntimeStatus: Sendable {
    var connection: RuntimeConnection
    var activeThemeID: String?
    var activeThemeName: String?
    var codexVersion: String?
    var port: Int?
    var persistenceEnabled: Bool
    var lastVerifiedAt: String?
    var diagnosticLogPath: String?
    var message: String

    static let unknown = RuntimeStatus(
        connection: .unavailable,
        activeThemeID: nil,
        activeThemeName: nil,
        codexVersion: nil,
        port: nil,
        persistenceEnabled: false,
        lastVerifiedAt: nil,
        diagnosticLogPath: nil,
        message: "Codex runtime has not been checked yet."
    )
}

struct ApplyResult: Sendable {
    var verified: Bool
    var message: String
    var runtime: RuntimeStatus
}

struct ThemeLibraryResult: Sendable {
    var themes: [Theme]
    var curatedCount: Int
    var localCount: Int
    var managedPath: String
    var message: String
}
