import XCTest
@testable import CodexStudio

final class AbstractWallpaperTests: XCTestCase {
    func testRelativePreviewAndQuery() throws {
        let page = URL(string: "https://moewalls.com/abstract/example/")!
        let url = try AbstractWallpaperService.previewURL(html: #"<video src='/wp-content/uploads/preview/example.webm?x=1&amp;y=2'></video>"#, page: page)
        XCTAssertEqual(url.absoluteString, "https://moewalls.com/wp-content/uploads/preview/example.webm?x=1&y=2")
    }
    func testRejectsExternalAndNonMediaSources() {
        let page = URL(string: "https://moewalls.com/abstract/example/")!
        for html in [#"<video src='https://other.example/clip.mp4'>"#, #"<video src='file:///tmp/clip.mp4'>"#, "<html>No video</html>"] {
            XCTAssertThrowsError(try AbstractWallpaperService.previewURL(html: html, page: page))
        }
    }
}
