import { earlyPayloadFor } from "./theme-payload.mjs";

export function createTargetSetupTracker() {
  let activeTargetSetups = 0;
  const targetSetupWaiters = new Set();
  return {
    beginTargetSetup() { activeTargetSetups += 1; },
    finishTargetSetup() {
      activeTargetSetups = Math.max(0, activeTargetSetups - 1);
      if (activeTargetSetups !== 0) return;
      for (const resolve of targetSetupWaiters) resolve();
      targetSetupWaiters.clear();
    },
    async waitForTargetSetups(timeoutMs = 2500) {
      if (activeTargetSetups === 0) return;
      let timeout;
      let release;
      const completed = new Promise((resolve) => {
        release = resolve;
        targetSetupWaiters.add(resolve);
      });
      try {
        await Promise.race([
          completed,
          new Promise((_, reject) => {
            timeout = setTimeout(() => reject(new Error("Renderer setup did not quiesce for pause")), timeoutMs);
          }),
        ]);
      } finally {
        clearTimeout(timeout);
        targetSetupWaiters.delete(release);
      }
    },
  };
}

export function createEarlyScriptManager() {
  const registerEarly = async (session, payload, revision) => {
    const result = await session.send("Page.addScriptToEvaluateOnNewDocument", {
      source: earlyPayloadFor(payload, revision),
    });
    return result.identifier ?? null;
  };
  const removeEarlyIdentifier = async (record, identifier, { strict = false } = {}) => {
    if (!identifier) return true;
    if (record.session.closed) {
      if (strict) throw new Error("Renderer session closed before early script removal");
      return false;
    }
    try {
      await record.session.send(
        "Page.removeScriptToEvaluateOnNewDocument",
        { identifier },
        strict ? 1500 : 10000,
      );
      record.earlyScriptIds.delete(identifier);
      if (record.earlyScriptId === identifier) record.earlyScriptId = null;
      return true;
    } catch (error) {
      if (strict) throw error;
      return false;
    }
  };
  const removeEarly = async (record, { strict = false } = {}) => {
    const identifiers = new Set(record.earlyScriptIds);
    if (record.earlyScriptId) identifiers.add(record.earlyScriptId);
    const results = await Promise.all([...identifiers].map((identifier) =>
      removeEarlyIdentifier(record, identifier, { strict })));
    return results.every(Boolean);
  };
  const registerEarlyForRecord = async (record, payload, revision) => {
    const identifier = await registerEarly(record.session, payload, revision);
    if (identifier) record.earlyScriptIds.add(identifier);
    return identifier;
  };
  const invalidateEarly = async (record, { strict = false } = {}) => {
    record.needsLoadFallback = false;
    if (record.session.closed) {
      if (strict) throw new Error("Renderer session closed before pause invalidation");
    } else {
      await record.session.evaluate(`(() => {
        window.__CODEX_DREAM_SKIN_EARLY_GENERATION__ = ${JSON.stringify(`disabled:${process.pid}`)};
        window.__CODEX_DREAM_SKIN_DISABLED__ = true;
        return true;
      })()`, strict ? 1500 : 10000).catch((error) => {
        if (strict) throw error;
      });
    }
    return removeEarly(record, { strict });
  };
  return { invalidateEarly, registerEarlyForRecord, removeEarly, removeEarlyIdentifier };
}
