import Foundation

/// Media streams to disk. Redirects and download size stay bounded, including unknown-length responses.
final class MoeMediaDownload: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    let limit: Int64 = 512 * 1024 * 1024
    static func allowed(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "https" && ["moewalls.com", "go.moewalls.com"].contains(url.host ?? "")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(Self.allowed(request.url) ? request : nil)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > limit || totalBytesExpectedToWrite > limit { downloadTask.cancel() }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    static func save(_ url: URL, to destination: URL) async throws {
        guard allowed(url) else { throw ThemeImportError.invalidSource("Unsupported media source.") }
        let delegate = MoeMediaDownload()
        var request = URLRequest(url: url, timeoutInterval: 180)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        let (temporary, response) = try await URLSession.shared.download(for: request, delegate: delegate)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, allowed(response.url),
              size > 0, size <= delegate.limit,
              !(response.mimeType ?? "").contains("text/html") else {
            throw ThemeImportError.invalidSource("The source did not return supported media (maximum 512 MB). Open its source page.")
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}
