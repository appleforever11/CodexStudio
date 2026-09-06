import AppKit
import SwiftUI
import OSLog

extension StudioStore {
    func applySelectedTheme() {
        guard canApply, let selectedTheme else { return }
        let generation = UUID()
        applyGeneration = generation
        let requestedThemeID = selectedTheme.id
        cancelRuntimeRefresh()
        isApplying = true
        runtimePhase = .applying
        runtime.message = "Applying \(selectedTheme.name)…"
        showNotice("Applying \(selectedTheme.name)…")

        applyTask?.cancel()
        applyTask = Task { [weak self] in
            guard let self else { return }
            let result = await runtimeClient.apply(themeID: requestedThemeID)
            guard !Task.isCancelled, generation == applyGeneration else { return }
            isApplying = false
            runtime = result.runtime
            runtimePhase = result.verified ? .idle : .failed
            logger.info("Theme apply finished: \(requestedThemeID, privacy: .public), verified=\(result.verified, privacy: .public)")
            showNotice(result.message)
        }
    }

    func cancelRuntimeRefresh() {
        runtimeRefreshGeneration = UUID()
        runtimeCheckTask?.cancel()
        runtimeCheckTask = nil
        isRefreshingRuntime = false
    }

    func refreshRuntime() {
        guard !isRefreshingRuntime, !isApplying, !isLoading else { return }
        let generation = UUID()
        runtimeRefreshGeneration = generation
        isRefreshingRuntime = true
        runtimePhase = .checking
        runtimeCheckTask?.cancel()
        logger.debug("Checking Codex runtime status")
        runtimeCheckTask = Task { [weak self] in
            guard let self else { return }
            let status = await runtimeClient.status()
            guard !Task.isCancelled, generation == runtimeRefreshGeneration else { return }
            runtime = status
            isRefreshingRuntime = false
            runtimePhase = status.connection == .unavailable ? .failed : .idle
            logger.info("Runtime check finished: \(status.connection.rawValue, privacy: .public)")
        }
    }

    func restoreOriginal() {
        guard canApply else { return }
        cancelRuntimeRefresh()
        let generation = UUID()
        applyGeneration = generation
        isApplying = true
        runtimePhase = .recovering
        showNotice("Restoring the original Codex appearance…")
        applyTask?.cancel()
        applyTask = Task { [weak self] in
            guard let self else { return }
            let result = await runtimeClient.restoreOriginal()
            guard !Task.isCancelled, generation == applyGeneration else { return }
            isApplying = false
            runtime = result.runtime
            runtimePhase = result.verified ? .idle : .failed
            showNotice(result.message)
        }
    }

}
