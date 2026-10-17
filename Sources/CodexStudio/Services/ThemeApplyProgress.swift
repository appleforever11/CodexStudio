import Foundation

enum ThemeApplyProgress {
    static func message(since start: Date) -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexDreamSkinStudio/operation-state.plist")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date, modified >= start,
              let data = try? Data(contentsOf: url),
              let value = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              value["status"] as? String == "applying",
              let message = value["message"] as? String, !message.isEmpty
        else { return nil }
        return message
    }
}
