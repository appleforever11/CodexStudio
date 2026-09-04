import Foundation
import CryptoKit

/// Keeps DockDoor's Codex shortcuts stable across Codex and Codex Studio
/// updates. The themed pin launches the managed helper path but tracks the
/// official Codex bundle identifier, because that process owns the visible
/// windows and therefore DockDoor's active-state indicator. Explicit icon
/// paths keep both pins from falling back to stock or generic artwork.
///
/// DockDoor stores its profile model as JSON strings inside the user's
/// `com.ejbills.DockDoorPro` preferences domain. We only touch an app entry
/// whose path or bundle identifier belongs to Codex Studio; unrelated pins and
/// the rest of the user's DockDoor configuration are left unchanged.
struct DockDoorIntegrationService {
    private static let preferenceDomain = "com.ejbills.DockDoorPro"
    private static let dockProfilesKey = "dockProfiles"
    private static let hiddenRunningAppsKey = "hiddenRunningApps"
    private static let officialCodexBundleIdentifier = "com.openai.codex"
    private static let themedLauncherBundleIdentifier = "com.codexthemes.themed-codex-launcher"
    private static let codexStudioBundleIdentifier = "local.kevinhowe.CodexStudio"
    private static let themedDockDoorIconFileName = "CodexStudio-CodexDark.icns"
    private static let studioDockDoorIconFileName = "CodexStudio-AppIcon.icns"

    @discardableResult
    static func repairIfNeeded() -> Bool {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        guard dockDoorIsInstalledOrConfigured(home: home),
              let defaults = UserDefaults(suiteName: preferenceDomain),
              var profiles = defaults.array(forKey: dockProfilesKey) as? [String],
              !profiles.isEmpty
        else {
            return false
        }

        let helperPaths = managedLauncherPaths(home: home)
        let studioPaths = managedStudioPaths(home: home)
        let themedIconDestination = dockDoorIconDestination(
            home: home,
            fileName: themedDockDoorIconFileName
        )
        let studioIconDestination = dockDoorIconDestination(
            home: home,
            fileName: versionedIconFileName(source: bundledStudioDockDoorIcon())
        )
        var foundManagedPin = false
        var foundStudioPin = false
        var changed = false

        for index in profiles.indices {
            guard let data = profiles[index].data(using: .utf8),
                  var root = try? JSONSerialization.jsonObject(with: data)
            else {
                continue
            }

            let profileChanged = repairJSON(
                &root,
                helperPaths: helperPaths,
                studioPaths: studioPaths,
                themedCustomIconPath: nil,
                studioCustomIconPath: nil,
                foundManagedPin: &foundManagedPin,
                foundStudioPin: &foundStudioPin
            )
            guard profileChanged,
                  let encoded = try? JSONSerialization.data(
                      withJSONObject: root,
                      options: [.sortedKeys]
                  ),
                  let profile = String(data: encoded, encoding: .utf8)
            else {
                continue
            }

            profiles[index] = profile
            changed = true
        }

        guard foundManagedPin || foundStudioPin else {
            return false
        }

        var themedCustomIconPath: String?
        if foundManagedPin,
           let themedIconDestination,
           installDockDoorIcon(from: bundledThemedDockDoorIcon(), to: themedIconDestination)
            || fileManager.isReadableFile(atPath: themedIconDestination.path) {
            themedCustomIconPath = themedIconDestination.path
        }

        var studioCustomIconPath: String?
        if foundStudioPin,
           let studioIconDestination,
           installDockDoorIcon(from: bundledStudioDockDoorIcon(), to: studioIconDestination)
            || fileManager.isReadableFile(atPath: studioIconDestination.path) {
            studioCustomIconPath = studioIconDestination.path
        }

        if themedCustomIconPath != nil || studioCustomIconPath != nil {
            // Re-run the small profile rewrite after each icon has been copied.
            // This avoids pointing DockDoor at a path that could not be created.
            for index in profiles.indices {
                guard let data = profiles[index].data(using: .utf8),
                      var root = try? JSONSerialization.jsonObject(with: data)
                else {
                    continue
                }
                let profileChanged = repairJSON(
                    &root,
                    helperPaths: helperPaths,
                    studioPaths: studioPaths,
                    themedCustomIconPath: themedCustomIconPath,
                    studioCustomIconPath: studioCustomIconPath,
                    foundManagedPin: &foundManagedPin,
                    foundStudioPin: &foundStudioPin
                )
                guard profileChanged,
                      let encoded = try? JSONSerialization.data(
                          withJSONObject: root,
                          options: [.sortedKeys]
                      ),
                      let profile = String(data: encoded, encoding: .utf8)
                else {
                    continue
                }
                profiles[index] = profile
                changed = true
            }
        }

        if foundManagedPin {
            var hiddenApps = defaults.stringArray(forKey: hiddenRunningAppsKey) ?? []
            let originalCount = hiddenApps.count
            hiddenApps.removeAll { $0 == officialCodexBundleIdentifier }
            if hiddenApps.count != originalCount {
                defaults.set(hiddenApps, forKey: hiddenRunningAppsKey)
                changed = true
            }
        }

        if changed {
            defaults.set(profiles, forKey: dockProfilesKey)
            _ = defaults.synchronize()
        }
        return changed
    }

    private static func dockDoorIsInstalledOrConfigured(home: URL) -> Bool {
        let fileManager = FileManager.default
        let installedApplications = [
            URL(fileURLWithPath: "/Applications/DockDoor Pro.app", isDirectory: true),
            home.appendingPathComponent("Applications/DockDoor Pro.app", isDirectory: true)
        ]
        let preferenceFile = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("com.ejbills.DockDoorPro.plist")
        let supportDirectory = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("DockDoorPro", isDirectory: true)

        return installedApplications.contains(where: { fileManager.fileExists(atPath: $0.path) })
            || fileManager.fileExists(atPath: preferenceFile.path)
            || fileManager.fileExists(atPath: supportDirectory.path)
    }

    private static func managedLauncherPaths(home: URL) -> Set<String> {
        let candidates = [
            URL(fileURLWithPath: "/Applications/Codex Themed.app", isDirectory: true),
            home.appendingPathComponent("Applications/Codex Themed.app", isDirectory: true)
        ]
        return Set(candidates.map { $0.standardizedFileURL.path })
    }

    private static func managedStudioPaths(home: URL) -> Set<String> {
        let candidates = [
            URL(fileURLWithPath: "/Applications/CodexStudio.app", isDirectory: true),
            home.appendingPathComponent("Applications/CodexStudio.app", isDirectory: true)
        ]
        return Set(candidates.map { $0.standardizedFileURL.path })
    }

    private static func dockDoorIconDestination(home: URL, fileName: String) -> URL? {
        let directory = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("DockDoorPro", isDirectory: true)
            .appendingPathComponent("CustomIcons", isDirectory: true)
        return directory.appendingPathComponent(fileName)
    }

    private static func bundledThemedDockDoorIcon() -> URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("CodexThemedLauncherTemplate", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("CodexDarkDockDoor.icns")
    }

    private static func bundledStudioDockDoorIcon() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("CodexStudio.icns")
    }

    // A new path invalidates consumers that cache custom images by URL. Keep
    // old files intact for other saved profiles and never clear DockDoor caches.
    static func versionedIconFileName(source: URL?) -> String {
        guard let source, let data = try? Data(contentsOf: source), !data.isEmpty else {
            return studioDockDoorIconFileName
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return "CodexStudio-AppIcon-\(digest).icns"
    }

    @discardableResult
    private static func installDockDoorIcon(from source: URL?, to destination: URL) -> Bool {
        guard let source,
              FileManager.default.isReadableFile(atPath: source.path)
        else {
            return false
        }

        let fileManager = FileManager.default
        if fileManager.contentsEqual(atPath: source.path, andPath: destination.path) {
            return true
        }

        let temporaryName = ".\(destination.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).icns"
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(temporaryName)
        do {
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.copyItem(at: source, to: temporary)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: temporary, to: destination)
            return true
        } catch {
            try? fileManager.removeItem(at: temporary)
            return false
        }
    }

    static func repairJSON(
        _ value: inout Any,
        helperPaths: Set<String>,
        studioPaths: Set<String>,
        themedCustomIconPath: String?,
        studioCustomIconPath: String?,
        foundManagedPin: inout Bool,
        foundStudioPin: inout Bool
    ) -> Bool {
        if var dictionary = value as? [String: Any] {
            var changed = false

            if isManagedLauncherEntry(dictionary, helperPaths: helperPaths) {
                foundManagedPin = true
                if dictionary["bundleIdentifier"] as? String != officialCodexBundleIdentifier {
                    dictionary["bundleIdentifier"] = officialCodexBundleIdentifier
                    changed = true
                }
                if let themedCustomIconPath,
                   dictionary["customIconPath"] as? String != themedCustomIconPath {
                    dictionary["customIconPath"] = themedCustomIconPath
                    changed = true
                }
                if let name = dictionary["name"] as? String,
                   ["ChatGPT", "Codex Studio (Themed)"].contains(name) {
                    dictionary["name"] = "Codex"
                    changed = true
                }
            }

            if isManagedStudioEntry(dictionary, studioPaths: studioPaths) {
                foundStudioPin = true
                if dictionary["bundleIdentifier"] as? String != codexStudioBundleIdentifier {
                    dictionary["bundleIdentifier"] = codexStudioBundleIdentifier
                    changed = true
                }
                if let studioCustomIconPath,
                   dictionary["customIconPath"] as? String != studioCustomIconPath {
                    dictionary["customIconPath"] = studioCustomIconPath
                    changed = true
                }
                if let name = dictionary["name"] as? String,
                   name != "Codex Studio" {
                    dictionary["name"] = "Codex Studio"
                    changed = true
                }
            }

            for key in dictionary.keys {
                guard var child = dictionary[key] else { continue }
                if repairJSON(
                    &child,
                    helperPaths: helperPaths,
                    studioPaths: studioPaths,
                    themedCustomIconPath: themedCustomIconPath,
                    studioCustomIconPath: studioCustomIconPath,
                    foundManagedPin: &foundManagedPin,
                    foundStudioPin: &foundStudioPin
                ) {
                    dictionary[key] = child
                    changed = true
                }
            }

            value = dictionary
            return changed
        }

        if var array = value as? [Any] {
            var changed = false
            for index in array.indices {
                if repairJSON(
                    &array[index],
                    helperPaths: helperPaths,
                    studioPaths: studioPaths,
                    themedCustomIconPath: themedCustomIconPath,
                    studioCustomIconPath: studioCustomIconPath,
                    foundManagedPin: &foundManagedPin,
                    foundStudioPin: &foundStudioPin
                ) {
                    changed = true
                }
            }
            value = array
            return changed
        }

        return false
    }

    private static func isManagedLauncherEntry(
        _ dictionary: [String: Any],
        helperPaths: Set<String>
    ) -> Bool {
        if dictionary["bundleIdentifier"] as? String == themedLauncherBundleIdentifier {
            return true
        }

        guard dictionary["bundleIdentifier"] as? String == officialCodexBundleIdentifier,
              let applicationPath = dictionary["applicationPath"] as? String
        else {
            return false
        }
        return helperPaths.contains(URL(fileURLWithPath: applicationPath).standardizedFileURL.path)
    }

    private static func isManagedStudioEntry(
        _ dictionary: [String: Any],
        studioPaths: Set<String>
    ) -> Bool {
        if dictionary["bundleIdentifier"] as? String == codexStudioBundleIdentifier {
            return true
        }

        guard let applicationPath = dictionary["applicationPath"] as? String else {
            return false
        }
        return studioPaths.contains(URL(fileURLWithPath: applicationPath).standardizedFileURL.path)
    }
}
