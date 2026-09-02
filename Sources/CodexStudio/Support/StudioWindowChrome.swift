import AppKit
import SwiftUI

/// Gives the SwiftUI surface access to the small part of NSWindow that
/// SwiftUI does not expose reliably: extending content into the titlebar
/// while retaining the native traffic-light controls.
struct StudioWindowChromeConfigurator: NSViewRepresentable {
    static func configure(window: NSWindow) {
        WindowChromeView.configure(window: window)
    }

    func makeNSView(context: Context) -> WindowChromeView {
        WindowChromeView()
    }

    func updateNSView(_ nsView: WindowChromeView, context: Context) {
        nsView.configureWindow()
    }
}

final class WindowChromeView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
        DispatchQueue.main.async { [weak self] in
            self?.configureWindow()
        }
    }

    func configureWindow() {
        guard let window else { return }

        Self.configure(window: window)
    }

    static func configure(window: NSWindow) {

        // The full-size content mask is the piece that removes the reserved
        // client-area gap. Transparent titlebar treatment then lets the
        // StudioWindowHeader provide the one continuous visual surface.
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
    }
}
