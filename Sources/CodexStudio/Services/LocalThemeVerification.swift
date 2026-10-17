import AppKit
import Foundation

/// Explicit local acceptance mode. Runs the same store action as Apply and
/// writes a bounded report; it is never enabled by normal app launches.
@MainActor
enum LocalThemeVerification {
    static func runIfRequested(store: StudioStore) async {
        let arguments = ProcessInfo.processInfo.arguments
        let restoring = arguments.contains("--verify-local-restore-process")
        let flag = restoring ? "--verify-local-restore-process" : "--verify-local-theme-process"
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 2) else { return }
        let themeID = arguments[index + 1]
        let report = URL(fileURLWithPath: arguments[index + 2])
        guard report.isFileURL, report.path.hasPrefix("/"),
              store.themes.contains(where: { $0.id == themeID }) else { return }
        store.selectedThemeID = themeID
        let started = Date()
        if restoring { store.restoreOriginal() } else { store.applySelectedTheme() }
        while store.isApplying, Date().timeIntervalSince(started) < 180 {
            try? await Task.sleep(for: .milliseconds(200))
        }
        let result: [String: Any] = [
            "themeID": themeID,
            "restoring": restoring,
            "activeThemeID": store.runtime.activeThemeID ?? "",
            "connection": store.runtime.connection.rawValue,
            "phase": store.runtimePhase.rawValue,
            "message": store.runtime.message,
            "notice": store.notice ?? "",
            "helper": ThemeHelperService.statusLabel,
            "elapsedSeconds": Date().timeIntervalSince(started),
            "bundlePath": Bundle.main.bundlePath,
            "windowCount": NSApp.windows.count,
            "finished": !store.isApplying
        ]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: report, options: .atomic)
        }
    }
}
