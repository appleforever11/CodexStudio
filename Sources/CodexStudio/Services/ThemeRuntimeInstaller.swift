// Runtime installation and DockDoor launcher repair.

import Foundation
import Darwin

extension ThemeLibraryService {

    static var bundledDockDoorLauncherDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("CodexThemedLauncherTemplate", isDirectory: true)
    }

    static var installedRuntimeDirectory: URL {
        homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("codex-dream-skin-studio", isDirectory: true)
    }

    static let dockDoorLauncherBundleIdentifier = "com.codexthemes.themed-codex-launcher"

    static var dockDoorLauncherCandidates: [URL] {
        [
            URL(fileURLWithPath: "/Applications/Codex Themed.app", isDirectory: true),
            homeDirectory
                .appendingPathComponent("Applications", isDirectory: true)
                .appendingPathComponent("Codex Themed.app", isDirectory: true)
        ]
    }

    @discardableResult
    static func installBundledRuntimeIfNeeded() -> Bool {
        let fileManager = FileManager.default
        guard let bundledRuntimeDirectory,
              fileManager.fileExists(atPath: bundledRuntimeDirectory.appendingPathComponent("scripts/switch-theme-macos.sh").path)
        else {
            return false
        }

        var changed = false
        if runtimeNeedsInstallation(bundledRuntimeDirectory: bundledRuntimeDirectory) {
            changed = installRuntimeAtomically(from: bundledRuntimeDirectory)
        }

        // The launcher is intentionally installed separately from the runtime.
        // This lets a Sparkle update repair an older DockDoor pin even when the
        // managed runtime is already at the same version.
        if installBundledDockDoorLauncher() {
            changed = true
        }

        // DockDoor can re-identify the helper as the official Codex process
        // after a shortcut is removed and re-pinned. Repair that mapping while
        // the bundled helper is being installed so the fix carries through
        // Sparkle updates to every Mac using DockDoor Pro.
        if DockDoorIntegrationService.repairIfNeeded() {
            changed = true
        }

        if changed {
            refreshInstalledPersistenceMonitor()
        }
        return changed
    }

    static func runtimeNeedsInstallation(bundledRuntimeDirectory: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: installedRuntimeDirectory.path) else {
            return true
        }
        guard let bundledVersion = runtimeVersion(at: bundledRuntimeDirectory),
              let installedVersion = runtimeVersion(at: installedRuntimeDirectory)
        else {
            // Preserve an existing runtime whose provenance/version cannot be
            // established. The launcher can still be refreshed independently.
            return false
        }
        return isVersion(bundledVersion, newerThan: installedVersion)
    }

    static func runtimeVersion(at directory: URL) -> [Int]? {
        let versionURL = directory.appendingPathComponent("VERSION")
        guard let raw = try? String(contentsOf: versionURL, encoding: .utf8) else {
            return nil
        }
        let components = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
        guard !components.isEmpty else { return nil }
        let values = components.compactMap { Int($0) }
        return values.count == components.count ? values : nil
    }

    static func isVersion(_ candidate: [Int], newerThan installed: [Int]) -> Bool {
        let count = max(candidate.count, installed.count)
        for index in 0..<count {
            let candidateValue = index < candidate.count ? candidate[index] : 0
            let installedValue = index < installed.count ? installed[index] : 0
            if candidateValue != installedValue {
                return candidateValue > installedValue
            }
        }
        return false
    }

    static func installRuntimeAtomically(from bundledRuntimeDirectory: URL) -> Bool {
        let fileManager = FileManager.default
        let codexDirectory = installedRuntimeDirectory.deletingLastPathComponent()
        let stagingDirectory = codexDirectory.appendingPathComponent(
            ".codex-dream-skin-studio.installing-\(UUID().uuidString)",
            isDirectory: true
        )
        let backupDirectory = codexDirectory.appendingPathComponent(
            ".codex-dream-skin-studio.previous-\(UUID().uuidString)",
            isDirectory: true
        )
        var movedExisting = false

        do {
            try fileManager.createDirectory(
                at: codexDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.copyItem(at: bundledRuntimeDirectory, to: stagingDirectory)
            let stagedScript = stagingDirectory.appendingPathComponent("scripts/switch-theme-macos.sh")
            guard fileManager.isReadableFile(atPath: stagedScript.path) else {
                try? fileManager.removeItem(at: stagingDirectory)
                return false
            }
            if fileManager.fileExists(atPath: installedRuntimeDirectory.path) {
                try fileManager.moveItem(at: installedRuntimeDirectory, to: backupDirectory)
                movedExisting = true
            }
            try fileManager.moveItem(at: stagingDirectory, to: installedRuntimeDirectory)
            normalizeRuntimePermissions(at: installedRuntimeDirectory)
            if movedExisting {
                try? fileManager.removeItem(at: backupDirectory)
            }
            return true
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            if movedExisting,
               !fileManager.fileExists(atPath: installedRuntimeDirectory.path),
               fileManager.fileExists(atPath: backupDirectory.path) {
                try? fileManager.moveItem(at: backupDirectory, to: installedRuntimeDirectory)
            }
            return false
        }
    }

    static func installBundledDockDoorLauncher() -> Bool {
        let fileManager = FileManager.default
        guard let source = bundledDockDoorLauncherDirectory,
              isManagedDockDoorLauncher(source),
              fileManager.fileExists(atPath: source.appendingPathComponent("Contents/MacOS/CodexThemedLauncher").path)
        else {
            return false
        }

        let existingDestination = dockDoorLauncherCandidates.first(where: isManagedDockDoorLauncher)
        let destination: URL
        if let existingDestination {
            destination = existingDestination
        } else if let writableDestination = dockDoorLauncherCandidates.first(where: { candidate in
            !fileManager.fileExists(atPath: candidate.path) && writableParent(of: candidate)
        }) {
            destination = writableDestination
        } else {
            // Never overwrite an unrelated app with the familiar DockDoor name.
            return false
        }

        let sourceInfo = source.appendingPathComponent("Contents/Info.plist")
        let destinationInfo = destination.appendingPathComponent("Contents/Info.plist")
        let sourceVersion = bundleValue("CFBundleVersion", at: sourceInfo)
        let destinationVersion = bundleValue("CFBundleVersion", at: destinationInfo)
        let sourceExecutable = source.appendingPathComponent("Contents/MacOS/CodexThemedLauncher")
        let destinationExecutable = destination.appendingPathComponent("Contents/MacOS/CodexThemedLauncher")
        if fileManager.fileExists(atPath: destination.path),
           sourceVersion == destinationVersion,
           fileManager.contentsEqual(atPath: sourceExecutable.path, andPath: destinationExecutable.path) {
            return false
        }

        let parent = destination.deletingLastPathComponent()
        let staging = parent.appendingPathComponent(
            ".Codex Themed.app.installing-\(UUID().uuidString)",
            isDirectory: true
        )
        let backup = parent.appendingPathComponent(
            ".Codex Themed.app.previous-\(UUID().uuidString)",
            isDirectory: true
        )
        var movedExisting = false

        do {
            try fileManager.copyItem(at: source, to: staging)
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: staging.appendingPathComponent("Contents/MacOS/CodexThemedLauncher").path
            )
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.moveItem(at: destination, to: backup)
                movedExisting = true
            }
            try fileManager.moveItem(at: staging, to: destination)
            if movedExisting {
                try? fileManager.removeItem(at: backup)
            }
            return true
        } catch {
            try? fileManager.removeItem(at: staging)
            if movedExisting,
               !fileManager.fileExists(atPath: destination.path),
               fileManager.fileExists(atPath: backup.path) {
                try? fileManager.moveItem(at: backup, to: destination)
            }
            return false
        }
    }

    static func writableParent(of url: URL) -> Bool {
        let fileManager = FileManager.default
        let parent = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path), parent.path == homeDirectory.appendingPathComponent("Applications").path {
            try? fileManager.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
        }
        return fileManager.isWritableFile(atPath: parent.path)
    }

    static func isManagedDockDoorLauncher(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path),
              bundleValue("CFBundleIdentifier", at: url.appendingPathComponent("Contents/Info.plist")) == dockDoorLauncherBundleIdentifier
        else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/MacOS/CodexThemedLauncher").path)
    }

    static func bundleValue(_ key: String, at infoURL: URL) -> String? {
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return nil
        }
        return plist[key] as? String
    }

    static func refreshInstalledPersistenceMonitor() {
        let agent = homeDirectory
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("com.codexthemes.theme-monitor.plist")
        guard FileManager.default.fileExists(atPath: agent.path) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kickstart", "-k", "gui/\(getuid())/com.codexthemes.theme-monitor"]
        try? process.run()
        process.waitUntilExit()
    }


}
