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
        guard FileManager.default.fileExists(atPath: themeURL.appendingPathComponent("theme.json").path) else {
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

        let output = run(script: script, arguments: ["--id", themeID], timeout: 35)
        guard output.completed, output.exitCode == 0 else {
            let detail = output.detail.isEmpty ? "The theme switch did not complete." : output.detail
            return ApplyResult(verified: false, message: detail, runtime: readStatus())
        }

        let runtime = readStatus()
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
        guard let data = try? Data(contentsOf: stateURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return RuntimeStatus(
                connection: .unavailable,
                activeThemeID: nil,
                activeThemeName: nil,
                codexVersion: nil,
                port: nil,
                message: "No managed Codex theme runtime was found."
            )
        }

        let session = object["session"] as? String
        let activeID = object["appliedThemeId"] as? String
        let activeName = object["appliedThemeName"] as? String
        let version = object["codexVersion"] as? String
        let port = (object["port"] as? NSNumber)?.intValue
        let connection: RuntimeConnection = session == "active" && activeID != nil ? .connected : .offline
        let message: String
        switch connection {
        case .connected:
            message = "Live theme runtime ready on port \(port.map(String.init) ?? "9341")."
        case .offline:
            message = "Codex theme runtime is installed but not currently active."
        case .unavailable:
            message = "No managed Codex theme runtime was found."
        }

        return RuntimeStatus(
            connection: connection,
            activeThemeID: activeID,
            activeThemeName: activeName,
            codexVersion: version,
            port: port,
            message: message
        )
    }

    private static func run(script: URL, arguments: [String], timeout: TimeInterval) -> ProcessOutput {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path] + arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        process.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        ]

        do {
            try process.run()
        } catch {
            return ProcessOutput(completed: false, exitCode: -1, detail: "Could not start the Codex runtime: \(error.localizedDescription)")
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return ProcessOutput(completed: false, exitCode: -1, detail: "The Codex theme runtime timed out before verification.")
        }

        let stdout = String(data: standardOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
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

private struct ProcessOutput: Sendable {
    let completed: Bool
    let exitCode: Int32
    let detail: String
}
