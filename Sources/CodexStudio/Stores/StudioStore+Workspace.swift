import Foundation

extension StudioStore {
    func applyWorkspaceAppearance(undo: Bool = false) {
        guard canApply else { return }
        cancelRuntimeRefresh()
        let generation = UUID()
        applyGeneration = generation
        isApplying = true
        runtimePhase = .applying
        let requested = workspaceAppearance
        applyTask?.cancel()
        applyTask = Task { [weak self] in
            guard let self else { return }
            let error = await WorkspaceAppearanceService.apply(requested, undo: undo)
            guard !Task.isCancelled, generation == applyGeneration else { return }
            isApplying = false
            workspaceAppearanceMessage = error ?? (undo ? "Previous appearance restored." : "Workspace appearance applied and verified.")
            if error == nil {
                workspaceAppearance = (try? WorkspaceAppearanceService().read()) ?? .init()
            }
            runtimePhase = error == nil ? .idle : .failed
            showNotice(workspaceAppearanceMessage)
            refreshRuntime()
        }
    }
}
