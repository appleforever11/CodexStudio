import XCTest
@testable import CodexStudio

final class WorkspaceAppearanceTests: XCTestCase {
    func testOlderAppearanceGetsDotDefaults() throws {
        let old = try JSONDecoder().decode(WorkspaceAppearance.self, from: Data("{\"chatBlur\":12}".utf8))
        XCTAssertEqual(old.dotBubbleColor, "#315A89")
        XCTAssertEqual(old.dotUserBubbleColor, "#414955")
        var custom = old
        custom.dotSpacing = 24
        custom.dotBubbleColor = "#334455"
        let saved = try JSONEncoder().encode(custom)
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceAppearance.self, from: saved), custom)
    }

    func testApplyUndoAndVerificationRollback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = WorkspaceAppearanceService(directory: root)
        var appearance = WorkspaceAppearance()
        appearance.chatOpacity = 0.65
        try service.change(appearance, verify: {})
        XCTAssertEqual(try service.read(), appearance)
        try service.change(nil, undo: true, verify: {})
        XCTAssertEqual(try service.read(), WorkspaceAppearance())
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("workspace-ui.json").path))
        try service.change(nil, undo: true, verify: {})
        XCTAssertEqual(try service.read(), appearance)
        var changed = appearance
        changed.sidebarBlur = 12
        XCTAssertThrowsError(try service.change(changed) { throw CocoaError(.fileReadUnknown) })
        XCTAssertEqual(try service.read(), appearance)
    }
}
