import Foundation

/// Media streams to disk. Redirects and download size stay bounded, including unknown-length responses.
final class MoeMediaDownload: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    static let maximumBytes: Int64 = 512 * 1024 * 1024
    let limit = maximumBytes
    private let stateLock = NSLock()
    private var exceededLimit = false
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
        if totalBytesWritten > limit || totalBytesExpectedToWrite > limit {
            stateLock.withLock { exceededLimit = true }
            downloadTask.cancel()
        }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    static func save(_ url: URL, to destination: URL) async throws {
        guard allowed(url) else { throw ThemeImportError.invalidSource("Unsupported media source.") }
        let delegate = MoeMediaDownload()
        var request = URLRequest(url: url, timeoutInterval: 180)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        let temporary: URL
        let response: URLResponse
        do { (temporary, response) = try await URLSession.shared.download(for: request, delegate: delegate) }
        catch {
            if delegate.stateLock.withLock({ delegate.exceededLimit }) { throw MoeMediaError.tooLarge }
            throw error
        }
        defer { try? FileManager.default.removeItem(at: temporary) }
        let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        try validate(response: response, size: Int64(size))
        try FileManager.default.moveItem(at: temporary, to: destination)
    }

    static func validate(response: URLResponse, size: Int64) throws {
        guard allowed(response.url) else { throw MoeMediaError.untrusted }
        guard let http = response as? HTTPURLResponse else { throw MoeMediaError.invalidResponse }
        if response.url?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "error-file" || http.statusCode == 404 {
            throw MoeMediaError.unavailable
        }
        if http.statusCode == 429 { throw MoeMediaError.rateLimited }
        guard http.statusCode == 200 else { throw MoeMediaError.httpStatus(http.statusCode) }
        guard size <= maximumBytes else { throw MoeMediaError.tooLarge }
        guard size > 0 else { throw MoeMediaError.empty }
        guard !(response.mimeType ?? "").lowercased().contains("html") else { throw MoeMediaError.invalidResponse }
    }
}


enum MoeMediaError: LocalizedError, Equatable {
    case unavailable, rateLimited, tooLarge, empty, invalidResponse, untrusted
    case httpStatus(Int)
    var errorDescription: String? {
        switch self {
        case .unavailable: "MoeWalls returned a file-not-found response. This download is unavailable right now. Choose Preview quality or retry later."
        case .rateLimited: "MoeWalls is limiting downloads. Wait a few minutes, then retry."
        case .tooLarge: "This source file exceeds the 512 MB download limit. Choose Preview quality for a smaller download."
        case .empty: "MoeWalls returned an empty download. Please retry later or choose another quality."
        case .invalidResponse: "MoeWalls returned a web page instead of media. Please retry later or check the source page."
        case .untrusted: "The download redirected outside the supported MoeWalls sources. Check the source page."
        case .httpStatus(let code): "MoeWalls could not serve this download (HTTP \(code)). Please retry later."
        }
    }
}
