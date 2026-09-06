import AppKit
import SwiftUI
import OSLog

extension StudioStore {
    func saveEditorDraft() {
        guard let selectedTheme else { return }
        let title = "\(selectedTheme.name) Variation"
        let safeName = title.lowercased().map { character in
            character.isLetter || character.isNumber ? String(character) : "-"
        }.joined().split(separator: "-").joined(separator: "-")
        let directory = ThemeLibraryService.homeDirectory
            .appendingPathComponent("Library/Application Support/CodexStudio/Drafts", isDirectory: true)
        let url = directory.appendingPathComponent("\(safeName)-\(Int(Date().timeIntervalSince1970)).json")
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "kind": "codex-studio-draft",
            "name": title,
            "referenceThemeID": selectedTheme.id,
            "accent": draftAccent.hexDescription,
            "panelOpacity": draftOpacity,
            "backdropBlur": draftBlur,
            "cornerRadius": draftRadius,
            "previewMode": previewMode.rawValue,
            "selectedSurface": selectedSurface.rawValue,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            showNotice("Saved \(title) to your Codex Studio drafts.")
        } catch {
            showNotice("Could not save the draft: \(error.localizedDescription)")
        }
    }

    func setMotionEnabled(_ enabled: Bool) {
        motionEnabled = enabled
        defaults.set(enabled, forKey: Keys.motionEnabled)
    }

    func resetEditorControls(for theme: Theme) {
        draftAccent = Color(hex: theme.palette.accent)
        draftOpacity = theme.id.contains("obsidian") ? 0.94 : 0.78
        draftBlur = theme.id.contains("obsidian") ? 4 : 18
        draftRadius = theme.id.contains("obsidian") ? 8 : 22
    }

}
