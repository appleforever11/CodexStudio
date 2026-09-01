import { connectTarget, listVerifiedTargets, waitForCodexProbe } from "./cdp-session.mjs";
import {
  earlyPayloadFor,
  invalidateStaticPayloadAssets,
  loadPayload,
} from "./theme-payload.mjs";
import {
  bestEffortOperationUi,
  nextOperationToken,
  operationKindMessage,
  presentOperationUi,
} from "./operation-ui.mjs";
import {
  cleanupExcludedSurface,
  waitForVerifiedSession,
} from "./renderer-verification.mjs";
import {
  isFreshBusyOperation,
  watchOperationState,
  watchPayloadSources,
  writeModeAck,
} from "./watch-sources.mjs";
import { createEarlyScriptManager, createTargetSetupTracker } from "./watch-support.mjs";

const applyToSession = (session, payload) => session.evaluate(payload);

export async function runWatch(options) {
  let current = await loadPayload(options.themeDir);
  const sessions = new Map();
  const rejected = new Set();
  let stopping = false;
  let reloadTimer = null;
  let reloadChain = Promise.resolve();
  let discoveryDelayMs = 100;
  let lastListErrorAt = 0;
  let operationSignalChain = Promise.resolve();
  let activeOperation = null;
  let pauseRecovery = null;
  let controlOnly = false;
  let mutationEpoch = 0;
  let wakeControlWait = null;
  const targetSetup = createTargetSetupTracker();
  const early = createEarlyScriptManager();

  const wakeControlLoop = () => {
    const wake = wakeControlWait;
    wakeControlWait = null;
    wake?.();
  };
  const waitForControlOperation = () => new Promise((resolve) => {
    let settled = false;
    const finish = () => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (wakeControlWait === finish) wakeControlWait = null;
      resolve();
    };
    const timer = setTimeout(finish, 60000);
    wakeControlWait = finish;
  });
  const stop = () => {
    stopping = true;
    wakeControlLoop();
  };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);

  const releaseControlSessions = () => {
    for (const record of sessions.values()) record.session.close();
    sessions.clear();
  };
  const restoreAfterAbortedPause = async (operation) => {
    mutationEpoch += 1;
    controlOnly = false;
    pauseRecovery = {
      token: operation.token,
      message: operation.message || "Pause failed; the original skin was restored",
    };
    releaseControlSessions();
    wakeControlLoop();
  };

  const refreshPayload = async () => {
    const refreshEpoch = mutationEpoch;
    let next;
    try {
      next = await loadPayload(options.themeDir);
    } catch (error) {
      await Promise.all([...sessions.values()].map(async (record) => {
        if (record.session.closed) return;
        const externalOperation = activeOperation;
        const operationToken = externalOperation?.token ?? nextOperationToken();
        record.operationToken = operationToken;
        record.operationExternal = Boolean(externalOperation);
        await presentOperationUi(
          record.session,
          operationToken,
          externalOperation ? "loading" : "error",
          externalOperation ? "Preparing theme…" : "The theme could not be read; the current skin is unchanged",
        );
      }));
      throw error;
    }
    if (next.revision === current.revision) return;
    current = next;
    if (controlOnly || mutationEpoch !== refreshEpoch) {
      console.log(`[dream-skin] staged theme ${current.theme.id} while skin is paused`);
      return;
    }
    for (const record of sessions.values()) {
      const { session } = record;
      if (session.closed) continue;
      const externalOperation = activeOperation;
      const operationToken = externalOperation?.token ?? nextOperationToken();
      record.operationToken = operationToken;
      record.operationExternal = Boolean(externalOperation);
      try {
        await presentOperationUi(session, operationToken, "loading", `Applying “${current.theme.name}”…`);
        if (controlOnly || mutationEpoch !== refreshEpoch) continue;
        const nextIdentifier = await early.registerEarlyForRecord(
          record, current.payload, current.revision,
        );
        if (controlOnly || mutationEpoch !== refreshEpoch) {
          await early.removeEarlyIdentifier(record, nextIdentifier);
          continue;
        }
        if (record.earlyScriptId) await early.removeEarlyIdentifier(record, record.earlyScriptId);
        record.earlyScriptId = nextIdentifier;
        record.needsLoadFallback = !nextIdentifier;
        await applyToSession(session, current.payload);
        if (controlOnly || mutationEpoch !== refreshEpoch) continue;
        const verification = await waitForVerifiedSession(
          session, Math.min(options.timeoutMs, 8000), current.theme.id, current.revision,
        );
        if (!verification?.pass) throw new Error("Theme refresh verification failed");
        if (!externalOperation) {
          await presentOperationUi(session, operationToken, "success", `Applied “${current.theme.name}”`);
        }
      } catch (error) {
        record.needsLoadFallback = true;
        if (!externalOperation) {
          await presentOperationUi(session, operationToken, "error", "Theme switch failed; application was not confirmed");
        }
        console.error(`[dream-skin] theme refresh failed: ${error.message}`);
      }
    }
    console.log(`[dream-skin] refreshed theme ${current.theme.id} (${current.timings.buildMs}ms)`);
  };

  const queuePayloadRefresh = ({ staticChanged = false } = {}) => {
    if (staticChanged) invalidateStaticPayloadAssets();
    if (reloadTimer) clearTimeout(reloadTimer);
    reloadTimer = setTimeout(() => {
      reloadTimer = null;
      reloadChain = reloadChain.then(refreshPayload).catch((error) => {
        console.error(`[dream-skin] theme reload failed: ${error.message}`);
      });
    }, 45);
  };
  const closePayloadWatchers = watchPayloadSources(options.themeDir, queuePayloadRefresh);
  const closeOperationWatcher = await watchOperationState(options.operationState, (operation) => {
    operationSignalChain = operationSignalChain.then(async () => {
      const previousOperation = activeOperation?.token === operation.token ? activeOperation : null;
      const busy = isFreshBusyOperation(operation);
      if (pauseRecovery && pauseRecovery.token !== operation.token) pauseRecovery = null;
      if (busy) {
        activeOperation = operation;
        wakeControlLoop();
      } else if (activeOperation?.token === operation.token) activeOperation = null;
      const abortedPause = !busy
        && (operation.status === "failed" || operation.status === "cancelled")
        && previousOperation?.status === "pausing";
      const pauseState = (busy && operation.status === "pausing") || operation.status === "paused";
      if (pauseState && !controlOnly) {
        controlOnly = true;
        mutationEpoch += 1;
      }
      await Promise.all([...sessions.values()].map(async (record) => {
        if (record.session.closed) return;
        if (busy) {
          const kind = operation.status === "pausing" ? "pause" : "apply";
          record.operationToken = operation.token;
          record.operationExternal = true;
          await presentOperationUi(
            record.session, operation.token, "loading", operationKindMessage(kind), 1000,
          );
          return;
        }
        if (record.operationToken !== operation.token) return;
        const state = operation.status === "failed" ? "error"
          : operation.status === "cancelled" ? "cancelled"
            : operation.status === "success" || operation.status === "paused" ? "success" : null;
        if (!state) return;
        await presentOperationUi(
          record.session,
          operation.token,
          state,
          operation.message || (state === "error" ? "Operation failed; try again" : "Operation complete"),
        );
      }));
      if (busy && operation.status === "pausing") {
        await reloadChain.catch(() => {});
        await targetSetup.waitForTargetSetups();
        await Promise.all([...sessions.values()].map((record) =>
          early.invalidateEarly(record, { strict: true })));
        await writeModeAck(options.operationAck, operation.token, "control");
      } else if (abortedPause) await restoreAfterAbortedPause(operation);
      else if (operation.status === "paused") {
        await reloadChain.catch(() => {});
        await targetSetup.waitForTargetSetups().catch(() => {});
        await Promise.all([...sessions.values()].map((record) =>
          early.invalidateEarly(record, { strict: true }))).catch((error) => {
          console.error(`[dream-skin] final pause invalidation failed: ${error.message}`);
        });
        releaseControlSessions();
      }
    }).catch((error) => {
      console.error(`[dream-skin] operation progress failed: ${error.message}`);
    });
    return operationSignalChain;
  });

  try {
    while (!stopping) {
      if (activeOperation && !isFreshBusyOperation(activeOperation)) {
        const expiredOperation = activeOperation;
        activeOperation = null;
        await Promise.all([...sessions.values()].map(async (record) => {
          if (record.session.closed || record.operationToken !== expiredOperation.token) return;
          await presentOperationUi(record.session, expiredOperation.token, "error", "Operation timed out; try again", 1000);
        }));
        if (expiredOperation.status === "pausing") {
          controlOnly = true;
          releaseControlSessions();
        }
      }
      if (controlOnly && !activeOperation) {
        releaseControlSessions();
        await waitForControlOperation();
        continue;
      }

      let targets = [];
      try {
        targets = await listVerifiedTargets(options.port);
        discoveryDelayMs = 100;
      } catch (error) {
        if (Date.now() - lastListErrorAt >= 2000) {
          console.error(`[dream-skin] ${new Date().toISOString()} ${error.message}`);
          lastListErrorAt = Date.now();
        }
        await new Promise((resolve) => setTimeout(resolve, discoveryDelayMs));
        discoveryDelayMs = Math.min(500, Math.round(discoveryDelayMs * 1.6));
        continue;
      }
      if (controlOnly && !activeOperation) {
        releaseControlSessions();
        continue;
      }

      const activeIds = new Set(targets.map((target) => target.id));
      for (const [id, record] of sessions) {
        if (!activeIds.has(id) || record.session.closed) {
          if (!record.session.closed && record.operationToken && !record.operationExternal) {
            await bestEffortOperationUi(record.session, "hide", record.operationToken, "loading", "");
          }
          record.session.close();
          sessions.delete(id);
        }
      }

      const cycleRecovery = activeOperation ? null : pauseRecovery;
      let recoveredPauseThisCycle = false;
      let recoveryFailedThisCycle = false;
      for (const target of targets) {
        if (sessions.has(target.id)) continue;
        let session;
        let record;
        let connectionEpoch;
        let recoveryOperation = cycleRecovery;
        targetSetup.beginTargetSetup();
        try {
          session = await connectTarget(target, options.port);
          record = {
            session,
            earlyScriptId: null,
            earlyScriptIds: new Set(),
            needsLoadFallback: false,
            operationToken: null,
            operationExternal: false,
          };
          connectionEpoch = mutationEpoch;
          sessions.set(target.id, record);
          session.on("Page.loadEventFired", () => {
            if (!record.needsLoadFallback) return;
            const fallbackEpoch = mutationEpoch;
            setTimeout(() => {
              if (session.closed || controlOnly || mutationEpoch !== fallbackEpoch || !record.needsLoadFallback) return;
              applyToSession(session, current.payload).catch((error) => {
                console.error(`[dream-skin] fallback reinject failed: ${error.message}`);
              });
            }, 0);
          });
          const initialOperation = activeOperation;
          recoveryOperation = initialOperation ? null : cycleRecovery;
          const pausing = initialOperation?.status === "pausing";
          if (!controlOnly) {
            try {
              record.earlyScriptId = await early.registerEarlyForRecord(
                record, current.payload, current.revision,
              );
              await session.evaluate(earlyPayloadFor(current.payload, current.revision));
            } catch (error) {
              record.needsLoadFallback = true;
              console.error(`[dream-skin] early injection unavailable: ${error.message}`);
            }
          }
          const probe = await waitForCodexProbe(session);
          if (!probe?.codex) {
            await early.removeEarly(record);
            if (probe?.excludedPetSurface && !await cleanupExcludedSurface(session)) {
              throw new Error("Excluded Pet surface cleanup did not verify");
            }
            session.close();
            sessions.delete(target.id);
            if (!probe?.excludedPetSurface && !rejected.has(target.id)) {
              console.error(`[dream-skin] rejected non-ChatGPT app target ${target.id}`);
              rejected.add(target.id);
            }
            if (probe?.excludedPetSurface) rejected.delete(target.id);
            continue;
          }
          rejected.delete(target.id);
          if (controlOnly || pausing || mutationEpoch !== connectionEpoch) {
            await early.invalidateEarly(record);
          }
          if (controlOnly && !initialOperation) {
            console.log(`[dream-skin] connected control-only target ${target.id}`);
            continue;
          }
          record.operationToken = initialOperation?.token
            ?? recoveryOperation?.token ?? nextOperationToken();
          record.operationExternal = Boolean(initialOperation || recoveryOperation);
          await presentOperationUi(
            session,
            record.operationToken,
            "loading",
            initialOperation
              ? operationKindMessage(initialOperation.status === "pausing" ? "pause" : "apply")
              : recoveryOperation
                ? "Pause did not complete; restoring the original skin…"
                : `Applying “${current.theme.name}”…`,
          );
          if (controlOnly || pausing) continue;
          const earlyApplied = await session.evaluate(
            `window.__CODEX_DREAM_SKIN_EARLY_APPLIED__ === ${JSON.stringify(current.revision)}`,
          );
          if (!earlyApplied) {
            if (controlOnly || mutationEpoch !== connectionEpoch) {
              await early.invalidateEarly(record);
              continue;
            }
            await session.evaluate(
              `window.__CODEX_DREAM_SKIN_EARLY_GENERATION__ = ${JSON.stringify(`fallback:${current.revision}`)}`,
            );
            await applyToSession(session, current.payload);
          }
          if (controlOnly || mutationEpoch !== connectionEpoch) {
            await early.invalidateEarly(record);
            continue;
          }
          const verification = await waitForVerifiedSession(
            session, Math.min(options.timeoutMs, 8000), current.theme.id, current.revision,
          );
          if (!verification?.pass) throw new Error("Initial theme verification failed");
          if (recoveryOperation && !activeOperation && pauseRecovery?.token === recoveryOperation.token) {
            await presentOperationUi(session, recoveryOperation.token, "error", "Pause failed; the original skin was restored", 1000);
            recoveredPauseThisCycle = true;
          } else if (!record.operationExternal) {
            await presentOperationUi(session, record.operationToken, "success", `Applied “${current.theme.name}”`);
          }
          console.log(`[dream-skin] injected verified ChatGPT target ${target.id}`);
        } catch (error) {
          const recoveryStillCurrent = recoveryOperation && !activeOperation
            && pauseRecovery?.token === recoveryOperation.token;
          if (recoveryStillCurrent) recoveryFailedThisCycle = true;
          if (record?.operationToken && session && !session.closed) {
            if (recoveryStillCurrent) {
              await presentOperationUi(session, recoveryOperation.token, "error", "Pause failed; restoration of the original skin was not confirmed", 1000);
            } else if (!record.operationExternal) {
              await presentOperationUi(session, record.operationToken, "error", "Apply failed; display verification did not pass");
            }
          }
          if (record) await early.removeEarly(record);
          session?.close();
          sessions.delete(target.id);
          console.error(`[dream-skin] inject failed for ${target.id}: ${error.message}`);
        } finally {
          targetSetup.finishTargetSetup();
        }
      }
      if (recoveredPauseThisCycle && !recoveryFailedThisCycle && !activeOperation
        && cycleRecovery?.token === pauseRecovery?.token) {
        await writeModeAck(options.operationAck, cycleRecovery.token, "full");
        pauseRecovery = null;
      }
      const pollDelay = sessions.size ? 800 : (targets.length ? 250 : 100);
      await new Promise((resolve) => setTimeout(resolve, pollDelay));
    }
  } finally {
    if (reloadTimer) clearTimeout(reloadTimer);
    closePayloadWatchers();
    closeOperationWatcher();
    await reloadChain.catch(() => {});
    await operationSignalChain.catch(() => {});
    await Promise.all([...sessions.values()].map((record) =>
      record.operationToken && !record.operationExternal
        ? bestEffortOperationUi(record.session, "hide", record.operationToken, "loading", "")
        : Promise.resolve(false)));
    await Promise.all([...sessions.values()].map((record) => early.removeEarly(record)));
    for (const record of sessions.values()) record.session.close();
  }
}
