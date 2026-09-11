import OSLog

extension StudioStore {
    func refreshCapabilities() {
        guard !isInspectingCapabilities else { return }
        let generation = UUID()
        capabilityGeneration = generation
        isInspectingCapabilities = true
        capabilityTask?.cancel()
        logger.debug("Inspecting Codex app capabilities")
        capabilityTask = Task { [weak self] in
            guard let self else { return }
            let snapshot = await capabilityService.inspect()
            guard !Task.isCancelled, generation == capabilityGeneration else { return }
            capabilities = snapshot
            isInspectingCapabilities = false
            logger.info("Codex capability check finished: \(snapshot.health.rawValue, privacy: .public)")
        }
    }
}
