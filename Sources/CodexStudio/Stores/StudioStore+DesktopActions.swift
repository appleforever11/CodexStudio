import AppKit
import SwiftUI
import OSLog

extension StudioStore {
    func copyDiagnostics() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnosticsSnapshot.text, forType: .string)
        logger.info("Copied diagnostics summary")
        showNotice("Copied a safe diagnostics summary.")
    }

    func openSupportFolder() {
        let supportDirectory = ThemeLibraryService.managedThemesDirectory
            .deletingLastPathComponent()
        guard NSWorkspace.shared.open(supportDirectory) else {
            showNotice("The support folder could not be opened.")
            return
        }
        logger.info("Opened local support folder")
    }

    func openRuntimeLog() {
        guard let path = runtime.diagnosticLogPath else {
            showNotice("The recovery log is not available yet.")
            return
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            showNotice("No recovery attempts have been recorded yet.")
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openCodex() {
        guard !isOpeningCodex, !isApplying else { return }
        isOpeningCodex = true
        showNotice("Preparing themed Codex…")
        Task { [weak self] in
            guard let self else { return }
            _ = await Task.detached(priority: .userInitiated) {
                DockDoorIntegrationService.repairIfNeeded()
            }.value

            let appURL = ThemeLibraryService.installedDockDoorLauncherURL
                ?? URL(fileURLWithPath: "/Applications/ChatGPT.app")
            let opened = NSWorkspace.shared.open(appURL)
            isOpeningCodex = false
            if opened {
                showNotice("Opened themed Codex.")
            } else {
                showNotice("The themed Codex launcher could not be opened. Check that Codex is installed.")
            }
        }
    }

    func importThemeFolder() {
        let panel = NSOpenPanel()
        panel.title = "Import Codex theme folder"
        panel.message = "Choose an extracted folder containing theme.json and its image."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        showNotice("Validating theme package…")
        Task { [weak self] in
            do {
                let message = try await Task.detached(priority: .userInitiated) {
                    try ThemeLibraryService.importTheme(from: url)
                }.value
                guard let self else { return }
                await bootstrap(force: true)
                showNotice(message)
            } catch {
                self?.showNotice(error.localizedDescription)
            }
        }
    }

    func revealManagedThemes() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: sourceSummary.managedPath)
    }

}
