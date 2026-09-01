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
    var wallBuddyCount: Int
    var managedPath: String
    var wallBuddyPath: String
    var message: String
}
