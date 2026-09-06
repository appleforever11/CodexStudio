import XCTest
@testable import CodexStudio

final class RuntimeProcessRunnerTests: XCTestCase {
    private func run(_ source: String, timeout: TimeInterval = 1) throws -> ProcessOutput {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sh")
        try Data(source.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return RuntimeProcessRunner.run(script: url, arguments: [], timeout: timeout)
    }

    func testExitStatusIsPreserved() throws {
        let result = try run("exit 7")
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.exitCode, 7)
    }

    func testFinalDiagnosticIsCaptured() throws {
        let result = try run("echo first\necho final >&2\nexit 2")
        XCTAssertEqual(result.detail, "final")
        XCTAssertEqual(result.exitCode, 2)
    }

    func testInheritedOutputDoesNotHoldOperationOpen() throws {
        let started = Date()
        let result = try run("sleep 3 &\nexit 0")
        XCTAssertTrue(result.completed)
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    func testTimeoutDoesNotWaitForeverForIgnoredTermination() throws {
        let started = Date()
        let result = try run("trap '' TERM\nwhile :; do :; done", timeout: 0.1)
        XCTAssertFalse(result.completed)
        XCTAssertLessThan(Date().timeIntervalSince(started), 2.5)
    }
}
