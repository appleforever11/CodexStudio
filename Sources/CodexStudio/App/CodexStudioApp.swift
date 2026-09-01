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
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Check for Updates…") {
                    appDelegate.checkForUpdates()
                }
                .disabled(!appDelegate.canCheckForUpdates)
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
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
