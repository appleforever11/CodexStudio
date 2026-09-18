import XCTest
@testable import CodexStudio

final class LocalThemePackTests: XCTestCase {
    func testLocalOnlyPackRemainsDiscoverableWithoutBundledArtwork() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try writePack("ios-local", in: root)

        let themes = ThemeLibraryService.scanLocalThemePacks(in: root)
        XCTAssertEqual(themes.map(\.id), ["ios-local"])
        XCTAssertEqual(themes.first?.imagePath, root.appendingPathComponent("ios-local/background.png").path)
        XCTAssertEqual(themes.first?.rightsSummary, "Apple copyrighted artwork; local-only")
        XCTAssertEqual(themes.first?.isCurated, false)
        XCTAssertNotNil(ThemeLibraryService.localThemePack("ios-local", in: root))
    }

    func testIncompleteUnmarkedMismatchedAndLinkedPacksAreExcluded() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try writePack("valid", in: root)
        try writePack("unmarked", in: root, localOnly: false)
        try writePack("mismatch", in: root, manifestID: "different")
        try writePack("missing-image", in: root)
        try FileManager.default.removeItem(at: root.appendingPathComponent("missing-image/background.png"))
        try writePack("missing-license", in: root)
        try FileManager.default.removeItem(at: root.appendingPathComponent("missing-license/LICENSE.txt"))
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("linked"),
            withDestinationURL: root.appendingPathComponent("valid")
        )

        XCTAssertEqual(ThemeLibraryService.scanLocalThemePacks(in: root).map(\.id), ["valid"])
        XCTAssertNil(ThemeLibraryService.localThemePack("../valid", in: root))
        XCTAssertNil(ThemeLibraryService.localThemePack("valid", in: root.appendingPathComponent("absent")))
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writePack(
        _ id: String, in root: URL, localOnly: Bool = true, manifestID: String? = nil
    ) throws {
        let directory = root.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest: [String: Any] = ["schemaVersion": 1, "id": manifestID ?? id, "image": "background.png"]
        let catalog: [String: Any] = [
            "schemaVersion": 1, "localOnly": localOnly,
            "rightsStatus": "Apple copyrighted artwork; local-only",
            "sourceURL": "https://www.apple.com", "aiGenerated": false
        ]
        try JSONSerialization.data(withJSONObject: manifest).write(to: directory.appendingPathComponent("theme.json"))
        try JSONSerialization.data(withJSONObject: catalog).write(to: directory.appendingPathComponent("catalog.json"))
        try Data("Local-only artwork".utf8).write(to: directory.appendingPathComponent("LICENSE.txt"))
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jL1sAAAAASUVORK5CYII=")!
        try png.write(to: directory.appendingPathComponent("background.png"))
    }
}
