import AppKit
import Sparkle
import SwiftUI

@main
struct CodexStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = StudioStore()

    var body: some Scene {
        WindowGroup("Codex Studio", id: "main") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 1280, height: 760)
        .windowResizability(.automatic)
        // Let the app surface own one continuous header. The native traffic
        // lights remain available, but the system's opaque title strip no
        // longer creates a second visual bar above the Studio chrome.
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Check for Updates…") {
                    appDelegate.checkForUpdates()
                }
                .disabled(!appDelegate.canCheckForUpdates)
            }

            CommandMenu("Navigate") {
                Button("Canvas") {
                    store.selectSection(.canvas)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Live editor") {
                    store.selectSection(.editor)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Explore") {
                    store.selectThemes()
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Library") {
                    store.selectSection(.library)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Favorites") {
                    store.selectFavorites()
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Recently used") {
                    store.selectRecent()
                }
                .keyboardShortcut("6", modifiers: .command)

                Button("Settings") {
                    store.selectSection(.settings)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // WindowGroup creates its NSWindow just after the application launch
        // callback. Apply the titlebar treatment again on the next run-loop
        // turn so the scene's native window chrome cannot reintroduce a
        // reserved strip above the Studio header.
        DispatchQueue.main.async { [weak self] in
            self?.configureStudioWindows()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.configureStudioWindows()
        }
    }

    private func configureStudioWindows() {
        for window in NSApp.windows where window.title == "Codex Studio" {
            StudioWindowChromeConfigurator.configure(window: window)
        }
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
