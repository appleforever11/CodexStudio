import AppKit
import Foundation

struct CodexRuntimeClient: Sendable {
    private static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    private static var runtimeRoot: URL {
        homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("codex-dream-skin-studio", isDirectory: true)
    }

    private static var stateURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexDreamSkinStudio", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    func status() async -> RuntimeStatus {
        await Task.detached(priority: .utility) {
            Self.readStatus()
        }.value
    }

    func apply(themeID: String) async -> ApplyResult {
        await Task.detached(priority: .userInitiated) {
            Self.applySynchronously(themeID: themeID)
        }.value
    }

    func restoreOriginal() async -> ApplyResult {
        await Task.detached(priority: .userInitiated) {
            Self.restoreSynchronously()
        }.value
    }

    private static func applySynchronously(themeID: String) -> ApplyResult {
        guard isSafeThemeID(themeID) else {
            return ApplyResult(verified: false, message: "That theme id is not valid.", runtime: readStatus())
        }
        let themeURL = ThemeLibraryService.managedThemesDirectory.appendingPathComponent(themeID, isDirectory: true)
        let isManaged = FileManager.default.fileExists(atPath: themeURL.appendingPathComponent("theme.json").path)
            || ThemeLibraryService.installBundledThemeIfNeeded(themeID)
        guard isManaged else {
            return ApplyResult(verified: false, message: "\(themeID) is preview-only on this Mac because it is not in the managed library.", runtime: readStatus())
        }

        let script = runtimeRoot.appendingPathComponent("scripts/switch-theme-macos.sh")
        guard FileManager.default.isReadableFile(atPath: script.path) else {
            return ApplyResult(
                verified: false,
                message: "The Codex theme runtime is not installed. The live canvas is still available, but nothing was changed in Codex.",
                runtime: readStatus()
            )
        }

        // A cold start can spend up to 45 seconds waiting for the official
        // Codex renderer after an update. Keep the UI operation bounded, but
        // do not cut the verified recovery loop off before it can finish.
        let output = run(script: script, arguments: ["--id", themeID], timeout: 90)
        guard output.completed, output.exitCode == 0 else {
            let detail = output.detail.isEmpty ? "The theme switch did not complete." : output.detail
            return ApplyResult(verified: false, message: detail, runtime: readStatus())
        }

        let runtime = waitForVerifiedTheme(themeID: themeID)
        guard runtime.activeThemeID == themeID else {
            return ApplyResult(
                verified: false,
                message: "The switch command finished, but Codex did not verify \(themeID) as active.",
                runtime: runtime
            )
        }
        return ApplyResult(verified: true, message: "Applied \(runtime.activeThemeName ?? themeID) to Codex and verified the live runtime.", runtime: runtime)
    }

    private static func restoreSynchronously() -> ApplyResult {
        let script = runtimeRoot.appendingPathComponent("scripts/restore-dream-skin-macos.sh")
        guard FileManager.default.isReadableFile(atPath: script.path) else {
            return ApplyResult(verified: false, message: "The Codex theme runtime is not installed, so the original appearance was not changed.", runtime: readStatus())
        }
        let output = run(script: script, arguments: [], timeout: 30)
        guard output.completed, output.exitCode == 0 else {
            return ApplyResult(verified: false, message: output.detail.isEmpty ? "Could not restore the original appearance." : output.detail, runtime: readStatus())
        }
        return ApplyResult(verified: true, message: "Restored the original Codex appearance.", runtime: readStatus())
    }

    private static func readStatus() -> RuntimeStatus {
        var status = readStatusOnce()
        guard status.connection == .unavailable,
              FileManager.default.fileExists(atPath: stateURL.path)
        else {
            return status
        }

        // The runtime writes its state during relaunch. A short-lived partial
        // read should not make the entire Studio UI flash to "unavailable".
        for _ in 0..<3 {
            Thread.sleep(forTimeInterval: 0.06)
            status = readStatusOnce()
            if status.connection != .unavailable { break }
        }
        return status
    }

    private static func readStatusOnce() -> RuntimeStatus {
        guard let data = try? Data(contentsOf: stateURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return RuntimeStatus(
                connection: .unavailable,
                activeThemeID: nil,
                activeThemeName: nil,
                codexVersion: nil,
                port: nil,
                persistenceEnabled: false,
                lastVerifiedAt: nil,
                diagnosticLogPath: diagnosticLogURL.path,
                message: "No managed Codex theme runtime was found."
            )
        }

        let session = object["session"] as? String
        let activeID = object["appliedThemeId"] as? String
        let activeName = object["appliedThemeName"] as? String
        let version = object["codexVersion"] as? String
        let port = (object["port"] as? NSNumber)?.intValue
        let codexPID = (object["codexPid"] as? NSNumber)?.intValue ?? 0
        let codexIsRunning = codexPID > 0 && NSRunningApplication(processIdentifier: pid_t(codexPID)) != nil
        let persistenceEnabled = readPersistenceEnabled()
        let lastVerifiedAt = object["verifiedAt"] as? String
        let connection: RuntimeConnection = session == "active" && activeID != nil && codexIsRunning ? .connected : .offline
        let message: String
        switch connection {
        case .connected:
            let recovery = persistenceEnabled ? " Relaunch recovery is armed." : " Relaunch recovery is not armed."
            message = "Theme verified on port \(port.map(String.init) ?? "9341").\(recovery)"
        case .offline:
            message = session == "active" && activeID != nil
                ? "Saved theme is waiting for the themed Codex process."
                : "Codex theme runtime is installed but not currently active."
        case .unavailable:
            message = "No managed Codex theme runtime was found."
        }

        return RuntimeStatus(
            connection: connection,
            activeThemeID: activeID,
            activeThemeName: activeName,
            codexVersion: version,
            port: port,
            persistenceEnabled: persistenceEnabled,
            lastVerifiedAt: lastVerifiedAt,
            diagnosticLogPath: diagnosticLogURL.path,
            message: message
        )
    }

    private static func waitForVerifiedTheme(themeID: String, timeout: TimeInterval = 8) -> RuntimeStatus {
        let deadline = Date().addingTimeInterval(timeout)
        var runtime = readStatus()
        while Date() < deadline {
            if runtime.activeThemeID == themeID && runtime.connection == .connected {
                return runtime
            }
            Thread.sleep(forTimeInterval: 0.20)
            runtime = readStatus()
        }
        return runtime
    }

    private static var persistenceURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexDreamSkinStudio", isDirectory: true)
            .appendingPathComponent("theme-persistence.plist")
    }

    private static var diagnosticLogURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexDreamSkinStudio", isDirectory: true)
            .appendingPathComponent("theme-persistence.log")
    }

    private static func readPersistenceEnabled() -> Bool {
        guard let data = try? Data(contentsOf: persistenceURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return false
        }
        return (plist["enabled"] as? NSNumber)?.boolValue ?? (plist["enabled"] as? Bool ?? false)
    }

    private static func run(script: URL, arguments: [String], timeout: TimeInterval) -> ProcessOutput {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let stdoutCollector = ProcessDataCollector()
        let stderrCollector = ProcessDataCollector()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path] + arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        process.environment = environment

        do {
            try process.run()
        } catch {
            return ProcessOutput(completed: false, exitCode: -1, detail: "Could not start the Codex runtime: \(error.localizedDescription)")
        }

        standardOutput.fileHandleForReading.readabilityHandler = { handle in
            stdoutCollector.append(handle.availableData)
        }
        standardError.fileHandleForReading.readabilityHandler = { handle in
            stderrCollector.append(handle.availableData)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        var didTimeOut = false
        if process.isRunning {
            didTimeOut = true
            process.terminate()
            process.waitUntilExit()
        }

        standardOutput.fileHandleForReading.readabilityHandler = nil
        standardError.fileHandleForReading.readabilityHandler = nil
        stdoutCollector.append(standardOutput.fileHandleForReading.readDataToEndOfFile())
        stderrCollector.append(standardError.fileHandleForReading.readDataToEndOfFile())
        if didTimeOut {
            return ProcessOutput(completed: false, exitCode: -1, detail: "The Codex theme runtime timed out before verification.")
        }

        let stdout = String(data: stdoutCollector.data, encoding: .utf8) ?? ""
        let stderr = String(data: stderrCollector.data, encoding: .utf8) ?? ""
        let detail = (stderr.isEmpty ? stdout : stderr)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .last
            .map(String.init) ?? ""
        return ProcessOutput(completed: true, exitCode: process.terminationStatus, detail: detail)
    }

    private static func isSafeThemeID(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= 80, id.first?.isLetter == true || id.first?.isNumber == true else { return false }
        return id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-" }
    }
}

private final class ProcessDataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private struct ProcessOutput: Sendable {
    let completed: Bool
    let exitCode: Int32
    let detail: String
}
