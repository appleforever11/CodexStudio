import fs from "node:fs/promises";
import path from "node:path";
import { connectCodexTargets } from "./cdp-session.mjs";
import { runtimeVersion } from "./config.mjs";
import {
  assertPayloadIntegrity,
  loadPayload,
} from "./theme-payload.mjs";
import {
  bestEffortOperationUi,
  nextOperationToken,
  operationKindMessage,
  presentOperationUi,
} from "./operation-ui.mjs";
import {
  removeFromSession,
  verifyRemovedSession,
  waitForVerifiedSession,
} from "./renderer-verification.mjs";

export async function applyToSession(session, payload) {
  return session.evaluate(payload);
}

async function capture(session, outputPath) {
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  const result = await session.send("Page.captureScreenshot", {
    format: "png",
    fromSurface: true,
    captureBeyondViewport: false,
  });
  await fs.writeFile(outputPath, Buffer.from(result.data, "base64"));
}

export async function runBeginOperation(options) {
  const connected = await connectCodexTargets(options.port, options.timeoutMs);
  const operationToken = options.operationToken ?? nextOperationToken();
  let shown = false;
  try {
    const results = await Promise.all(connected.map(({ session }) => presentOperationUi(
      session,
      operationToken,
      "loading",
      operationKindMessage(options.operationKind),
      Math.max(250, Math.floor(options.timeoutMs / 2)),
    )));
    shown = results.some(Boolean);
  } finally {
    for (const { session } of connected) session.close();
  }
  if (!shown) throw new Error("Could not show operation progress in the verified ChatGPT renderer");
  process.stdout.write(`${operationToken}\n`);
}

export async function runFinishOperation(options) {
  const connected = await connectCodexTargets(options.port, options.timeoutMs);
  let shown = false;
  try {
    const results = await Promise.all(connected.map(({ session }) => presentOperationUi(
      session,
      options.operationToken,
      options.operationUiState,
      options.operationMessage,
      Math.max(250, Math.floor(options.timeoutMs / 2)),
    )));
    shown = results.some(Boolean);
  } finally {
    for (const { session } of connected) session.close();
  }
  if (!shown) throw new Error("Could not show the completed operation state in the verified ChatGPT renderer");
}

export async function runOneShot(options) {
  const connected = await connectCodexTargets(options.port, options.timeoutMs);
  const operationToken = options.mode === "once" || options.mode === "remove"
    ? options.operationToken ?? nextOperationToken() : null;
  if (operationToken) {
    const message = options.mode === "remove" ? "Pausing skin…" : "Preparing skin…";
    const action = options.operationToken ? presentOperationUi
      : (session, token, state, text) => bestEffortOperationUi(session, "show", token, state, text);
    await Promise.all(connected.map(({ session }) => action(
      session, operationToken, "loading", message,
    )));
  }

  let loaded = null;
  try {
    loaded = (options.mode === "once" || options.mode === "verify" || options.reload)
      ? await loadPayload(options.themeDir) : null;
  } catch (error) {
    if (operationToken) {
      await Promise.all(connected.map(({ session }) => presentOperationUi(
        session, operationToken, "error", "Skin preparation failed",
      )));
    }
    for (const { session } of connected) session.close();
    throw error;
  }

  const payload = loaded?.payload ?? null;
  const results = [];
  let screenshotCaptured = false;
  for (const { target, session, probe } of connected) {
    try {
      if (options.mode === "remove") await removeFromSession(session);
      else if (options.mode === "once") {
        await bestEffortOperationUi(
          session, "update", operationToken, "loading", `Applying “${loaded.theme.name}”…`,
        );
        await applyToSession(session, payload);
      }
      if (options.reload) {
        await session.send("Page.reload", { ignoreCache: true });
        await new Promise((resolve) => setTimeout(resolve, 1600));
        if (options.mode !== "remove") {
          if (operationToken) await presentOperationUi(
            session, operationToken, "loading", `Applying “${loaded.theme.name}”…`,
          );
          await applyToSession(session, payload);
        }
      }
      if (operationToken) await presentOperationUi(
        session,
        operationToken,
        "loading",
        options.mode === "remove" ? "Confirming skin is paused…" : "Checking display effects…",
      );
      const result = options.mode === "remove"
        ? await verifyRemovedSession(session)
        : await waitForVerifiedSession(
          session,
          options.timeoutMs,
          loaded?.theme.id ?? null,
          loaded?.revision ?? null,
        );
      results.push({ targetId: target.id, markers: probe?.markers, result });
      if (operationToken) {
        const passed = options.mode === "remove" ? result === true : result?.pass;
        await presentOperationUi(
          session,
          operationToken,
          passed ? "success" : "error",
          passed
            ? options.mode === "remove" ? "Skin paused" : `Applied “${loaded.theme.name}”`
            : options.mode === "remove" ? "Pause verification failed" : "Display verification failed",
        );
      }
      if (options.screenshot && !screenshotCaptured) {
        if (operationToken) await bestEffortOperationUi(session, "hide", operationToken, "loading", "");
        await capture(session, options.screenshot);
        screenshotCaptured = true;
      }
    } catch (error) {
      if (operationToken) await presentOperationUi(
        session,
        operationToken,
        "error",
        options.mode === "remove" ? "Pause failed. Try again." : "Apply failed. Try again.",
      );
      results.push({ targetId: target.id, markers: probe?.markers, error: error.message, result: null });
    } finally {
      session.close();
    }
  }

  console.log(JSON.stringify({
    mode: options.mode,
    version: runtimeVersion,
    port: options.port,
    targets: results,
  }, null, 2));
  const failed = results.length === 0 || results.some((item) =>
    item.error || (options.mode === "remove" ? item.result !== true : !item.result?.pass));
  if (failed) process.exitCode = 2;
}

export async function runOneShotAndExit(options) {
  await runOneShot(options);
  await new Promise((resolve) => process.stdout.write("", resolve));
  process.exit(process.exitCode ?? 0);
}

export { assertPayloadIntegrity };
