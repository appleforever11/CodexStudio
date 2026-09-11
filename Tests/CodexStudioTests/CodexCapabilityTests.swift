import XCTest
@testable import CodexStudio

final class CodexCapabilityTests: XCTestCase {
    func testTargetSummaryUsesClearRendererLanguage() {
        let summary = CodexTargetSummary(
            total: 3,
            codexPageCount: 1,
            excludedSurfaceCount: 1,
            webviewCount: 1,
            externalPageCount: 0,
            unsupportedCount: 0
        )
        XCTAssertEqual(summary.displayValue, "1 app page · 1 embedded webview")
    }

    func testHighlightsKeepImportantCapabilitiesVisibleWhenSomeAreMissing() {
        let snapshot = CodexCapabilitySnapshot(
            checkedAt: nil,
            health: .partial,
            message: "Partial",
            bundleIdentifier: "com.openai.codex",
            bundlePath: nil,
            appVersion: "26.903.71938",
            appBuild: "8576",
            executableName: "ChatGPT",
            processID: nil,
            isRunning: false,
            installedRuntimeVersion: nil,
            recordedRuntimeVersion: nil,
            bundledRuntimeVersion: nil,
            port: 9341,
            browserVersion: nil,
            cdpProtocol: nil,
            targets: .unknown,
            bundledNodeVersion: nil,
            codexCLI: nil,
            appServerAvailable: false,
            features: [CodexCapabilityFeature(id: "plugins", stage: "stable", enabled: true)]
        )

        XCTAssertEqual(snapshot.enabledFeatureCount, 1)
        XCTAssertEqual(snapshot.highlightedFeatures.count, 8)
        XCTAssertEqual(snapshot.feature(named: "plugins")?.availabilityLabel, "Available")
        XCTAssertEqual(snapshot.feature(named: "apps"), nil)
        XCTAssertEqual(snapshot.highlightedFeatures.first?.id, "apps")
    }
}
