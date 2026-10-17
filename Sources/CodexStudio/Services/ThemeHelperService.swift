import Foundation
import ServiceManagement

@MainActor
enum ThemeHelperService {
    static let identifier = "local.kevinhowe.CodexStudio.ThemeHelper"

    /// Only select the native backend once macOS confirms registration. A
    /// pending approval leaves the existing shell backend available.
    static var statusLabel: String {
        guard Bundle.main.bundleIdentifier == "local.kevinhowe.CodexStudio" else { return "Review build — registration disabled" }
        switch SMAppService.loginItem(identifier: identifier).status {
        case .enabled: return "Ready"
        case .requiresApproval: return "Allow in Login Items"
        case .notRegistered: return "Enabled on the next theme apply"
        case .notFound: return "Helper unavailable"
        @unknown default: return "Check Login Items"
        }
    }

    static func openSettings() { SMAppService.openSystemSettingsLoginItems() }

    static func disable() {
        guard Bundle.main.bundleIdentifier == "local.kevinhowe.CodexStudio" else { return }
        try? SMAppService.loginItem(identifier: identifier).unregister()
        let marker = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexDreamSkinStudio/native-theme-helper")
        try? FileManager.default.removeItem(at: marker)
    }

    static func prepare() -> String? {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/CodexStudioThemeHelper.app")
        guard Bundle.main.bundleIdentifier == "local.kevinhowe.CodexStudio",
              FileManager.default.fileExists(atPath: helper.path)
        else { return nil }
        let service = SMAppService.loginItem(identifier: identifier)
        do {
            if service.status == .notRegistered { try service.register() }
            guard service.status == .enabled else {
                return "Automatic recovery is using the existing monitor until the Studio helper is allowed in Login Items."
            }
            let state = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/CodexDreamSkinStudio")
            try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
            try Data(identifier.utf8).write(to: state.appendingPathComponent("native-theme-helper"), options: .atomic)
            return nil
        } catch {
            return "The theme can still apply; the existing recovery monitor will be used because the Studio helper could not register."
        }
    }
}
