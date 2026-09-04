import XCTest
@testable import CodexStudio

final class DockDoorIconTests: XCTestCase {
    func testIconRevisionChangesPathButIsStableForSameBytes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("icon.icns")
        try Data("first".utf8).write(to: source)
        let first = DockDoorIntegrationService.versionedIconFileName(source: source)
        XCTAssertEqual(first, DockDoorIntegrationService.versionedIconFileName(source: source))
        try Data("second".utf8).write(to: source)
        XCTAssertNotEqual(first, DockDoorIntegrationService.versionedIconFileName(source: source))
    }

    func testPinUpdatePreservesOtherAppsAndIsIdempotent() {
        let unrelated: [String: Any] = ["bundleIdentifier": "example.other", "customIconPath": "/custom/other.icns"]
        var value: Any = [
            ["bundleIdentifier": "local.kevinhowe.CodexStudio", "customIconPath": "/old.icns"],
            unrelated
        ]
        var helper = false
        var studio = false
        func repair() -> Bool {
            DockDoorIntegrationService.repairJSON(&value, helperPaths: [], studioPaths: [],
                themedCustomIconPath: nil, studioCustomIconPath: "/new-hash.icns",
                foundManagedPin: &helper, foundStudioPin: &studio)
        }
        XCTAssertTrue(repair())
        XCTAssertTrue(studio)
        XCTAssertFalse(helper)
        let entries = value as! [[String: Any]]
        XCTAssertEqual(entries[0]["customIconPath"] as? String, "/new-hash.icns")
        XCTAssertEqual(entries[1]["customIconPath"] as? String, "/custom/other.icns")
        XCTAssertFalse(repair())
    }
}
