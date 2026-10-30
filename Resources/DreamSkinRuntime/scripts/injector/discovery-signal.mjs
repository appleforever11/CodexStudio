// Events are hints: the validated HTTP inventory remains authoritative.
export function createDiscoverySignal() {
  let revision = 0;
  let finish = null;
  return {
    get revision() { return revision; },
    wake() { revision += 1; finish?.(); },
    wait(timeoutMs, observedRevision) {
      if (revision !== observedRevision) return Promise.resolve();
      return new Promise((resolve) => {
        const done = () => {
          clearTimeout(timer);
          if (finish === done) finish = null;
          resolve();
        };
        const timer = setTimeout(done, timeoutMs);
        finish = done;
      });
    },
  };
}

export async function enableTargetDiscovery(session, wake) {
  // Ignore high-volume worker/iframe changes. Never trust an event URL for attachment.
  const pages = new Set();
  const pageChanged = ({ targetInfo }) => {
    if (targetInfo?.type !== "page") return;
    pages.add(targetInfo.targetId);
    wake();
  };
  session.on("Target.targetCreated", pageChanged);
  session.on("Target.targetInfoChanged", pageChanged);
  session.on("Target.targetDestroyed", ({ targetId }) => {
    if (pages.delete(targetId)) wake();
  });
  session.ws.addEventListener("close", wake, { once: true });
  try {
    await session.send("Target.setDiscoverTargets", { discover: true }, 500);
    return true;
  } catch {
    // Older hosts may not expose this domain; retain the original polling path.
    return false;
  }
}

export async function ensureTargetDiscovery(records, wake) {
  const live = [...records].filter((record) => !record.session.closed);
  if (!live.some((record) => record.targetDiscovery)) {
    const candidate = live.find((record) => !record.targetDiscoveryAttempted);
    if (candidate) {
      candidate.targetDiscoveryAttempted = true;
      candidate.targetDiscovery = await enableTargetDiscovery(candidate.session, wake);
      console.log(`[dream-skin] target discovery ${candidate.targetDiscovery
        ? "events enabled (4000ms recovery poll)" : "polling fallback (800ms)"}`);
    }
  }
  return live.some((record) => record.targetDiscovery && !record.session.closed);
}
