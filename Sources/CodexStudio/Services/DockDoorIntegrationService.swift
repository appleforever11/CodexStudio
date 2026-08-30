import Foundation

/// Keeps DockDoor's themed Codex shortcut distinct from the official Codex
/// process that the theme runtime launches.
///
/// DockDoor stores its profile model as JSON strings inside the user's
/// `com.ejbills.DockDoorPro` preferences domain. We only touch an app entry
/// whose path points at our managed helper; unrelated ChatGPT/Codex pins and
/// the rest of the user's DockDoor configuration are left unchanged.
struct DockDoorIntegrationService {
    private static let preferenceDomain = "com.ejbills.DockDoorPro"
    private static let dockProfilesKey = "dockProfiles"
    private static let hiddenRunningAppsKey = "hiddenRunningApps"
    private static let officialCodexBundleIdentifier = "com.openai.codex"
    private static let themedLauncherBundleIdentifier = "com.codexthemes.themed-codex-launcher"
    private static let dockDoorIconFileName = "CodexStudio-CodexDark.icns"

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
        let iconDestination = dockDoorIconDestination(home: home)
        var foundManagedPin = false
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
                customIconPath: nil,
                foundManagedPin: &foundManagedPin
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

        guard foundManagedPin else {
            return false
        }

        if let iconDestination,
           installDockDoorIcon(from: bundledDockDoorIcon(), to: iconDestination) {
            // Re-run the small profile rewrite after the icon has been copied.
            // This avoids pointing DockDoor at a path that could not be
            // created while still making the custom icon deterministic.
            for index in profiles.indices {
                guard let data = profiles[index].data(using: .utf8),
                      var root = try? JSONSerialization.jsonObject(with: data)
                else {
                    continue
                }
                let profileChanged = repairJSON(
                    &root,
                    helperPaths: helperPaths,
                    customIconPath: iconDestination.path,
                    foundManagedPin: &foundManagedPin
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

        if !(defaults.stringArray(forKey: hiddenRunningAppsKey) ?? []).contains(officialCodexBundleIdentifier) {
            var hiddenApps = defaults.stringArray(forKey: hiddenRunningAppsKey) ?? []
            hiddenApps.append(officialCodexBundleIdentifier)
            defaults.set(hiddenApps, forKey: hiddenRunningAppsKey)
            changed = true
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

    private static func dockDoorIconDestination(home: URL) -> URL? {
        let directory = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("DockDoorPro", isDirectory: true)
            .appendingPathComponent("CustomIcons", isDirectory: true)
        return directory.appendingPathComponent(dockDoorIconFileName)
    }

    private static func bundledDockDoorIcon() -> URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("CodexThemedLauncherTemplate", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("CodexDark.icns")
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

        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".CodexStudio-CodexDark-\(UUID().uuidString).icns")
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

    private static func repairJSON(
        _ value: inout Any,
        helperPaths: Set<String>,
        customIconPath: String?,
        foundManagedPin: inout Bool
    ) -> Bool {
        if var dictionary = value as? [String: Any] {
            var changed = false

            if isManagedLauncherEntry(dictionary, helperPaths: helperPaths) {
                foundManagedPin = true
                if dictionary["bundleIdentifier"] as? String != themedLauncherBundleIdentifier {
                    dictionary["bundleIdentifier"] = themedLauncherBundleIdentifier
                    changed = true
                }
                if let customIconPath,
                   dictionary["customIconPath"] as? String != customIconPath {
                    dictionary["customIconPath"] = customIconPath
                    changed = true
                }
                if let name = dictionary["name"] as? String,
                   ["ChatGPT", "Codex Studio (Themed)"].contains(name) {
                    dictionary["name"] = "Codex"
                    changed = true
                }
            }

            for key in dictionary.keys {
                guard var child = dictionary[key] else { continue }
                if repairJSON(
                    &child,
                    helperPaths: helperPaths,
                    customIconPath: customIconPath,
                    foundManagedPin: &foundManagedPin
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
                    customIconPath: customIconPath,
                    foundManagedPin: &foundManagedPin
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
}
