import AppKit
import Foundation

/// Performs a read-only compatibility pass over the installed Codex app and
/// its loopback renderer. It deliberately does not attach to a renderer,
/// change a theme, start app-server, or inspect account data.
struct CodexCapabilityService: Sendable {
    private static let codexBundleIdentifier = "com.openai.codex"
    private static let defaultPort = 9341
    private static let curlURL = URL(fileURLWithPath: "/usr/bin/curl")

    func inspect() async -> CodexCapabilitySnapshot {
        await Task.detached(priority: .utility) {
            Self.inspectSynchronously()
        }.value
    }

    private static func inspectSynchronously() -> CodexCapabilitySnapshot {
        let state = readRuntimeState()
        let bundleURL = resolveCodexBundle(recordedPath: state.bundlePath)
        let bundleInfo = bundleURL.flatMap(readBundleInfo)
        let processID = runningProcessID(preferred: state.codexPID)
        let port = validPort(state.port) ?? defaultPort
        let cdp = inspectCDP(port: port)

        let installedRuntimeVersion = readVersion(at: installedRuntimeURL)
        let bundledRuntimeVersion = readVersion(at: bundledRuntimeURL)
        let codexURL = bundleURL?.appendingPathComponent("Contents/Resources/codex")
        let nodeURL = bundleURL?.appendingPathComponent("Contents/Resources/cua_node/bin/node")
        let codexCLI = codexURL.flatMap { readCommandVersion(executable: $0) }
        let bundledNodeVersion = nodeURL.flatMap { readCommandVersion(executable: $0) }
        let features = codexURL.map(readFeatures) ?? []
        let appServerAvailable = codexURL.map { supportsAppServer(executable: $0, features: features) } ?? false

        let isRunning = processID != nil
        let health = healthFor(
            bundleInfo: bundleInfo,
            state: state,
            isRunning: isRunning,
            cdp: cdp,
            installedRuntimeVersion: installedRuntimeVersion
        )
        let message = messageFor(
            bundleInfo: bundleInfo,
            state: state,
            processID: processID,
            port: port,
            cdp: cdp,
            installedRuntimeVersion: installedRuntimeVersion,
            bundledRuntimeVersion: bundledRuntimeVersion
        )

        return CodexCapabilitySnapshot(
            checkedAt: Date(),
            health: health,
            message: message,
            bundleIdentifier: bundleInfo?.identifier,
            bundlePath: bundleURL?.path,
            appVersion: bundleInfo?.version,
            appBuild: bundleInfo?.build,
            executableName: bundleInfo?.executable,
            processID: processID,
            isRunning: isRunning,
            installedRuntimeVersion: installedRuntimeVersion,
            recordedRuntimeVersion: state.runtimeVersion,
            bundledRuntimeVersion: bundledRuntimeVersion,
            port: port,
            browserVersion: cdp.browserVersion,
            cdpProtocol: cdp.protocolVersion,
            targets: cdp.targets,
            bundledNodeVersion: bundledNodeVersion,
            codexCLI: codexCLI,
            appServerAvailable: appServerAvailable,
            features: features
        )
    }

    private static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    private static var stateURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexDreamSkinStudio", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    private static var installedRuntimeURL: URL {
        homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("codex-dream-skin-studio", isDirectory: true)
    }

    private static var bundledRuntimeURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("DreamSkinRuntime", isDirectory: true)
    }

    private struct RuntimeState: Sendable {
        let bundlePath: String?
        let codexPID: Int32?
        let codexVersion: String?
        let port: Int?
        let runtimeVersion: String?
    }

    private struct BundleInfo: Sendable {
        let identifier: String
        let version: String?
        let build: String?
        let executable: String?
    }

    private struct CDPProbe: Sendable {
        let browserVersion: String?
        let protocolVersion: String?
        let targets: CodexTargetSummary
    }

    private static func readRuntimeState() -> RuntimeState {
        guard let data = try? Data(contentsOf: stateURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return RuntimeState(bundlePath: nil, codexPID: nil, codexVersion: nil, port: nil, runtimeVersion: nil)
        }

        let pid = (object["codexPid"] as? NSNumber)?.int32Value
        let port = (object["port"] as? NSNumber)?.intValue
        return RuntimeState(
            bundlePath: object["codexBundle"] as? String,
            codexPID: pid,
            codexVersion: object["codexVersion"] as? String,
            port: port,
            runtimeVersion: object["skinVersion"] as? String
        )
    }

    private static func resolveCodexBundle(recordedPath: String?) -> URL? {
        var candidates: [URL] = []
        if let recordedPath, !recordedPath.isEmpty {
            candidates.append(URL(fileURLWithPath: recordedPath, isDirectory: true))
        }
        candidates.append(contentsOf: [
            URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications/ChatGPT.app", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications/Codex.app", isDirectory: true),
        ])
        return candidates.first(where: { readBundleInfo(at: $0) != nil })
    }

    private static func readBundleInfo(at bundleURL: URL) -> BundleInfo? {
        let infoURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let identifier = plist["CFBundleIdentifier"] as? String,
              identifier == codexBundleIdentifier
        else {
            return nil
        }
        return BundleInfo(
            identifier: identifier,
            version: plist["CFBundleShortVersionString"] as? String,
            build: plist["CFBundleVersion"] as? String,
            executable: plist["CFBundleExecutable"] as? String
        )
    }

    private static func runningProcessID(preferred: Int32?) -> Int32? {
        if let preferred,
           preferred > 0,
           let process = NSRunningApplication(processIdentifier: pid_t(preferred)),
           process.bundleIdentifier == codexBundleIdentifier {
            return preferred
        }
        return NSRunningApplication.runningApplications(withBundleIdentifier: codexBundleIdentifier)
            .first(where: { !$0.isTerminated })?
            .processIdentifier
    }

    private static func validPort(_ port: Int?) -> Int? {
        guard let port, (1...65535).contains(port) else { return nil }
        return port
    }

    private static func readVersion(at directory: URL?) -> String? {
        guard let directory,
              let raw = try? String(contentsOf: directory.appendingPathComponent("VERSION"), encoding: .utf8)
        else { return nil }
        let version = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }

    private static func inspectCDP(port: Int) -> CDPProbe {
        let version = readJSONObject(url: "http://127.0.0.1:\(port)/json/version")
        let rawTargets = readJSONArray(url: "http://127.0.0.1:\(port)/json/list")
        let targets = rawTargets.map(parseTargetSummary) ?? .unknown
        return CDPProbe(
            browserVersion: version?["Browser"] as? String,
            protocolVersion: version?["Protocol-Version"] as? String,
            targets: targets
        )
    }

    private static func readJSONObject(url: String) -> [String: Any]? {
        guard let result = readLoopbackJSON(url: url),
              let object = try? JSONSerialization.jsonObject(with: result) as? [String: Any]
        else { return nil }
        return object
    }

    private static func readJSONArray(url: String) -> [[String: Any]]? {
        guard let result = readLoopbackJSON(url: url),
              let array = try? JSONSerialization.jsonObject(with: result) as? [[String: Any]]
        else { return nil }
        return array
    }

    private static func readLoopbackJSON(url: String) -> Data? {
        let result = LocalCommandRunner.run(
            executable: curlURL,
            arguments: [
                "--silent", "--show-error", "--fail",
                "--connect-timeout", "1", "--max-time", "2",
                "--noproxy", "*", url,
            ],
            timeout: 3
        )
        guard result.completed, result.exitCode == 0 else { return nil }
        return Data(result.stdout.utf8)
    }

    private static func parseTargetSummary(_ targets: [[String: Any]]) -> CodexTargetSummary {
        var codexPages = 0
        var excludedSurfaces = 0
        var webviews = 0
        var externalPages = 0
        var unsupported = 0

        for target in targets {
            let type = target["type"] as? String
            let url = target["url"] as? String ?? ""
            if type == "webview" {
                webviews += 1
            } else if type == "page" {
                guard url.hasPrefix("app://") else {
                    externalPages += 1
                    continue
                }
                if isExcludedSurface(url: url) {
                    excludedSurfaces += 1
                } else {
                    codexPages += 1
                }
            } else {
                unsupported += 1
            }
        }

        return CodexTargetSummary(
            total: targets.count,
            codexPageCount: codexPages,
            excludedSurfaceCount: excludedSurfaces,
            webviewCount: webviews,
            externalPageCount: externalPages,
            unsupportedCount: unsupported
        )
    }

    private static func isExcludedSurface(url: String) -> Bool {
        guard let components = URLComponents(string: url) else { return false }
        let initialRoute = components.queryItems?.first(where: { $0.name == "initialRoute" })?.value ?? ""
        return components.path.hasSuffix("/avatar-overlay-composition-surface.html")
            || initialRoute == "/avatar-overlay"
            || initialRoute.hasPrefix("/avatar-overlay/")
    }

    private static func readCommandVersion(executable: URL) -> String? {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { return nil }
        let result = LocalCommandRunner.run(executable: executable, arguments: ["--version"], timeout: 3)
        guard result.completed, result.exitCode == 0 else { return nil }
        return firstNonEmptyLine(result.stdout) ?? firstNonEmptyLine(result.stderr)
    }

    private static func readFeatures(executable: URL) -> [CodexCapabilityFeature] {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { return [] }
        let result = LocalCommandRunner.run(executable: executable, arguments: ["features", "list"], timeout: 4)
        guard result.completed, result.exitCode == 0 else { return [] }

        var features: [CodexCapabilityFeature] = []
        var seen = Set<String>()
        for line in result.stdout.split(whereSeparator: \.isNewline) {
            let columns = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard columns.count >= 3,
                  let id = columns.first.map(String.init),
                  !seen.contains(id),
                  let enabledText = columns.last.map(String.init)
            else { continue }
            let stage = columns.dropFirst().dropLast().map(String.init).joined(separator: " ")
            guard enabledText == "true" || enabledText == "false" else { continue }
            seen.insert(id)
            features.append(CodexCapabilityFeature(id: id, stage: stage, enabled: enabledText == "true"))
        }
        return features
    }

    private static func supportsAppServer(executable: URL, features: [CodexCapabilityFeature]) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { return false }
        if features.contains(where: { $0.id == "code_mode_host" && $0.enabled }) { return true }
        let result = LocalCommandRunner.run(executable: executable, arguments: ["app-server", "--help"], timeout: 3)
        return result.completed && result.exitCode == 0
            && (result.stdout + result.stderr).localizedCaseInsensitiveContains("app-server")
    }

    private static func healthFor(
        bundleInfo: BundleInfo?,
        state: RuntimeState,
        isRunning: Bool,
        cdp: CDPProbe,
        installedRuntimeVersion: String?
    ) -> CodexCapabilityHealth {
        guard bundleInfo != nil else { return .unavailable }
        if let expected = state.codexVersion,
           let actual = bundleInfo?.version,
           expected != actual {
            return .needsAttention
        }
        if let recorded = state.runtimeVersion,
           let installedRuntimeVersion,
           recorded != installedRuntimeVersion {
            return .needsAttention
        }
        guard isRunning else { return .partial }
        guard cdp.browserVersion != nil else { return .needsAttention }
        return cdp.targets.codexPageCount > 0 ? .ready : .partial
    }

    private static func messageFor(
        bundleInfo: BundleInfo?,
        state: RuntimeState,
        processID: Int32?,
        port: Int,
        cdp: CDPProbe,
        installedRuntimeVersion: String?,
        bundledRuntimeVersion: String?
    ) -> String {
        guard let bundleInfo else {
            return "A compatible ChatGPT app bundle was not found in the standard locations."
        }
        if let expected = state.codexVersion,
           let actual = bundleInfo.version,
           expected != actual {
            return "The running app is \(actual), but the runtime recorded Codex \(expected). Refresh after relaunching Codex."
        }
        if let recorded = state.runtimeVersion,
           let installedRuntimeVersion,
           recorded != installedRuntimeVersion {
            return "The runtime state and installed VERSION disagree (\(recorded) vs \(installedRuntimeVersion))."
        }
        if processID == nil {
            return "ChatGPT \(bundleInfo.version ?? "was found") is installed but is not running."
        }
        if cdp.browserVersion == nil {
            return "ChatGPT is running, but its loopback renderer inspector did not respond on port \(port)."
        }
        if cdp.targets.codexPageCount == 0 {
            return "The loopback inspector responded, but no main Codex app page is currently exposed."
        }
        if let bundledRuntimeVersion, bundledRuntimeVersion != installedRuntimeVersion {
            return "Codex \(bundleInfo.version ?? "is ready") is compatible. Studio runtime \(bundledRuntimeVersion) is bundled; installed runtime is \(installedRuntimeVersion ?? "not present") and will update on a production launch."
        }
        return "Codex \(bundleInfo.version ?? "is ready") is running with \(cdp.targets.displayValue)."
    }

    private static func firstNonEmptyLine(_ output: String) -> String? {
        output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }
}
