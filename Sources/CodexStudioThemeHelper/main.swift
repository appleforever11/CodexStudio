import AppKit
import Foundation

// One coordinator owns recovery. Workspace events replace the old two-second
// shell polling loop; the slower timer only checks health while Codex is open.
@MainActor
final class ThemeHelper {
    private var operation: Process?
    private var timeout: Timer?
    private var health: Timer?
    private var pending: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private let root = FileManager.default.homeDirectoryForCurrentUser
    private var state: URL { root.appendingPathComponent("Library/Application Support/CodexDreamSkinStudio") }

    func start() {
        try? FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
        try? Data(String(ProcessInfo.processInfo.processIdentifier).utf8)
            .write(to: state.appendingPathComponent("native-theme-helper.pid"), options: .atomic)
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if name == NSWorkspace.didLaunchApplicationNotification,
                   (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier != "com.openai.codex" {
                    return
                }
                Task { @MainActor in self?.schedule() }
            })
        }
        health = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.schedule() }
        }
        schedule()
    }

    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.recover() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func recover() {
        guard operation == nil,
              let data = try? Data(contentsOf: state.appendingPathComponent("theme-persistence.plist")),
              let config = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              config["enabled"] as? Bool == true,
              NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.openai.codex" })
        else { return }
        let script = root.appendingPathComponent(".codex/codex-dream-skin-studio/scripts/recover-theme-once-macos.sh")
        guard FileManager.default.isExecutableFile(atPath: script.path) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.timeout?.invalidate()
                self?.timeout = nil
                self?.operation = nil
            }
        }
        do {
            try process.run()
            operation = process
            timeout = Timer.scheduledTimer(withTimeInterval: 150, repeats: false) { _ in
                if process.isRunning { process.terminate() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
            }
        } catch { operation = nil }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let helper = ThemeHelper()
helper.start()
app.run()
