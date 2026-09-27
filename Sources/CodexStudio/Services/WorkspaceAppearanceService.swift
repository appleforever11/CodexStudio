import Foundation

/// Appearance history is separate from theme files and the pinned runtime backup.
struct WorkspaceAppearanceService: Sendable {
    static let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexDreamSkinStudio")
    let directory: URL
    init(directory: URL = Self.root) { self.directory = directory }
    private var current: URL { directory.appendingPathComponent("workspace-ui.json") }
    private var undoFile: URL { directory.appendingPathComponent("workspace-ui-undo.json") }
    private struct Undo: Codable { let contents: Data? }

    func read() throws -> WorkspaceAppearance {
        guard FileManager.default.fileExists(atPath: current.path) else { return .init() }
        return try JSONDecoder().decode(WorkspaceAppearance.self, from: Data(contentsOf: current))
    }

    /// Rolls the settings file back if the installed renderer does not verify.
    func change(_ value: WorkspaceAppearance?, undo: Bool = false,
                verify: () throws -> Void) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let before = fm.fileExists(atPath: current.path) ? try Data(contentsOf: current) : nil
        let next: Data?
        if undo {
            next = try JSONDecoder().decode(Undo.self, from: Data(contentsOf: undoFile)).contents
        } else {
            next = try JSONEncoder().encode(value ?? WorkspaceAppearance())
        }
        func write(_ data: Data?) throws {
            if let data { try data.write(to: current, options: .atomic) }
            else if fm.fileExists(atPath: current.path) { try fm.removeItem(at: current) }
        }
        try write(next)
        do { try verify() }
        catch {
            try write(before)
            // Reapply the previous appearance; retain the original error if this also fails.
            try? verify()
            throw error
        }
        try JSONEncoder().encode(Undo(contents: before)).write(to: undoFile, options: .atomic)
    }

    static func apply(_ value: WorkspaceAppearance, undo: Bool) async -> String? {
        await Task.detached(priority: .userInitiated) {
            do {
                let script = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".codex/codex-dream-skin-studio/scripts/refresh-workspace-ui-macos.sh")
                guard FileManager.default.fileExists(atPath: script.path) else {
                    return "This runtime needs the workspace appearance update before these controls can apply."
                }
                try Self().change(value, undo: undo) {
                    let result = RuntimeProcessRunner.run(script: script, arguments: [], timeout: 35)
                    guard result.completed && result.exitCode == 0 else {
                        throw NSError(domain: "WorkspaceAppearance", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: result.detail])
                    }
                }
                return nil
            } catch { return error.localizedDescription }
        }.value
    }

    static var pinnedRestorePoint: URL? {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexStudio/RestorePoints")
        guard let data = try? Data(contentsOf: root.appendingPathComponent("pinned.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = json["path"] as? String else { return nil }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.deletingLastPathComponent() == root.standardizedFileURL,
              FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path)
        else { return nil }
        return url
    }
}
