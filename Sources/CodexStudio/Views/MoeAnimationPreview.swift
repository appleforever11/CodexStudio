import SwiftUI
import WebKit

/// Isolated WebM playback avoids the crashing _AVKit_SwiftUI VideoPlayer wrapper.
/// Loads only our own document and the selected MoeWalls media; no source-page ads/scripts.
struct MoeAnimationPreview: NSViewRepresentable {
    let url: URL
    let onStatus: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onStatus: onStatus) }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(context.coordinator, name: "preview")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.onStatus = onStatus
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        view.loadHTMLString(Self.document(url: url), baseURL: nil)
    }
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.onStatus = { _ in }
        view.configuration.userContentController.removeScriptMessageHandler(forName: "preview")
        view.navigationDelegate = nil
        view.stopLoading()
        view.loadHTMLString("", baseURL: nil)
    }
    static func document(url: URL) -> String {
        guard url.scheme == "https", url.host == "moewalls.com", url.path.hasPrefix("/wp-content/uploads/") else { return "" }
        let escaped = url.absoluteString.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "<", with: "&lt;")
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; media-src https://moewalls.com; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
        <style>html,body{margin:0;width:100%;height:100%;background:#09090d;overflow:hidden}video{width:100%;height:100%;object-fit:contain}</style></head>
        <body><video id="preview" src="\(escaped)" controls autoplay muted loop playsinline></video>
        <script>
        const video=document.getElementById('preview');
        const report=text=>window.webkit.messageHandlers.preview.postMessage(text);
        video.addEventListener('timeupdate',()=>report(`Playing site preview · ${video.videoWidth} × ${video.videoHeight} · ${Math.floor(video.currentTime)}s`));
        video.addEventListener('pause',()=>report('Site preview paused'));
        video.addEventListener('waiting',()=>report('Loading site preview…'));
        video.addEventListener('error',()=>report('This site preview could not play. You can still choose a download quality or return to the image.'));
        video.play().catch(()=>report('Press Play in the preview to start animation.'));
        </script></body></html>
        """
    }

    @MainActor final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var loadedURL: URL?
        var onStatus: (String) -> Void
        init(onStatus: @escaping (String) -> Void) { self.onStatus = onStatus }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "preview", let text = message.body as? String else { return }
            onStatus(String(text.prefix(240)))
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            onStatus("The preview stopped. Return to the image and try Preview animation again.")
        }
    }
}
