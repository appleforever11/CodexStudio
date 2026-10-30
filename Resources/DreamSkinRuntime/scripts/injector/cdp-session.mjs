import {
  CDP_ID_PATTERN,
  LOOPBACK_HOSTS,
  selectorLiteral,
  stableTestidLiteral,
} from "./config.mjs";
import { cleanupExcludedSurface } from "./renderer-verification.mjs";
import {
  classifyCodexTarget,
  isCodexPageTarget,
  summarizeCodexTargets,
} from "./target-contract.mjs";

function validatedDebuggerUrl(target, port) {
  const url = new URL(target.webSocketDebuggerUrl);
  const pathIsValid = /^\/devtools\/page\/[A-Za-z0-9._-]{1,200}$/.test(url.pathname);
  if (url.protocol !== "ws:" || !LOOPBACK_HOSTS.has(url.hostname) || Number(url.port) !== port
    || url.username || url.password || url.search || url.hash || !pathIsValid) {
    throw new Error("Rejected a CDP WebSocket URL outside the allowed loopback page endpoint shape");
  }
  return url.href;
}

function isValidCdpPageTarget(item, port) {
  if (!isCodexPageTarget(item)
    || typeof item.id !== "string" || !CDP_ID_PATTERN.test(item.id) || !item.webSocketDebuggerUrl) return false;
  try {
    const debuggerUrl = new URL(validatedDebuggerUrl(item, port));
    return debuggerUrl.pathname === `/devtools/page/${item.id}`;
  } catch {
    return false;
  }
}

export class CdpSession {
  constructor(target, port) {
    this.target = target;
    this.ws = new WebSocket(validatedDebuggerUrl(target, port));
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
    this.closed = false;
  }

  async open() {
    await new Promise((resolve, reject) => {
      const cleanup = () => {
        clearTimeout(timeout);
        this.ws.removeEventListener("open", opened);
        this.ws.removeEventListener("error", failed);
        this.ws.removeEventListener("close", closed);
      };
      const opened = () => { cleanup(); resolve(); };
      const fail = (message) => {
        cleanup();
        this.close();
        reject(new Error(message));
      };
      const failed = () => fail("CDP WebSocket open failed");
      const closed = () => fail("CDP WebSocket closed before opening");
      const timeout = setTimeout(() => fail("CDP WebSocket open timed out"), 5000);
      this.ws.addEventListener("open", opened, { once: true });
      this.ws.addEventListener("error", failed, { once: true });
      this.ws.addEventListener("close", closed, { once: true });
    });
    this.ws.addEventListener("message", (event) => this.onMessage(event));
    this.ws.addEventListener("error", () => this.close());
    this.ws.addEventListener("close", () => {
      this.closed = true;
      for (const waiter of this.pending.values()) {
        clearTimeout(waiter.timeout);
        waiter.reject(new Error("CDP socket closed"));
      }
      this.pending.clear();
    });
    try {
      await Promise.all([this.send("Runtime.enable"), this.send("Page.enable")]);
    } catch (error) {
      this.close();
      throw error;
    }
    return this;
  }

  onMessage(event) {
    let message;
    try { message = JSON.parse(String(event.data)); } catch { this.close(); return; }
    if (!message || typeof message !== "object") { this.close(); return; }
    if (message.id) {
      const waiter = this.pending.get(message.id);
      if (!waiter) return;
      clearTimeout(waiter.timeout);
      this.pending.delete(message.id);
      if (message.error) {
        const error = new Error(`${message.error.message} (${message.error.code})`);
        error.cdpCode = message.error.code;
        waiter.reject(error);
      } else waiter.resolve(message.result);
      return;
    }
    for (const listener of this.listeners.get(message.method) ?? []) {
      try { listener(message.params ?? {}); } catch (error) {
        console.error(`[dream-skin] CDP listener failed: ${error.message}`);
      }
    }
  }

  on(method, listener) {
    const listeners = this.listeners.get(method) ?? [];
    listeners.push(listener);
    this.listeners.set(method, listeners);
  }

  send(method, params = {}, timeoutMs = 10000) {
    if (this.closed) return Promise.reject(new Error("CDP session is closed"));
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP command timed out: ${method}`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timeout });
      try {
        this.ws.send(JSON.stringify({ id, method, params }));
      } catch (error) {
        clearTimeout(timeout);
        this.pending.delete(id);
        reject(error);
      }
    });
  }

  async evaluate(expression, timeoutMs = 10000) {
    const result = await this.send("Runtime.evaluate", {
      expression, awaitPromise: true, returnByValue: true, userGesture: false,
    }, timeoutMs);
    if (result.exceptionDetails) {
      const detail = result.exceptionDetails.exception?.description ?? result.exceptionDetails.text;
      throw new Error(`Renderer evaluation failed: ${detail}`);
    }
    return result.result?.value;
  }

  close() {
    for (const waiter of this.pending.values()) {
      clearTimeout(waiter.timeout);
      waiter.reject(new Error("CDP session closed"));
    }
    this.pending.clear();
    if (!this.closed) {
      try { this.ws.close(); } catch {}
    }
    this.closed = true;
  }
}

async function fetchTargetList(port) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2000);
  try {
    const response = await fetch(`http://127.0.0.1:${port}/json/list`, {
      redirect: "error", signal: controller.signal,
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const targets = await response.json();
    if (!Array.isArray(targets)) throw new Error("CDP target list was not an array");
    return targets;
  } finally {
    clearTimeout(timeout);
  }
}

async function listAppTargets(port) {
  const targets = await fetchTargetList(port);
  return targets.filter((item) => isValidCdpPageTarget(item, port));
}

async function probeSession(session, timeoutMs = 10000) {
  return session.evaluate(`(() => {
    const initialRoute = new URLSearchParams(String(location.search || '')).get('initialRoute') || '';
    const pathname = String(location.pathname || '');
    const excludedPetSurface = location.protocol === 'app:' && (
      pathname.endsWith('/avatar-overlay-composition-surface.html') ||
      initialRoute === '/avatar-overlay' || initialRoute.startsWith('/avatar-overlay/')
    );
    const genericCodexSurface = () => {
      if (location.protocol !== 'app:') return false;
      const main = document.querySelector('main, [role="main"]');
      const input = document.querySelector('textarea, [contenteditable="true"], [role="textbox"]');
      const branded = Boolean(document.querySelector(${stableTestidLiteral("app-shell-header-context-menu-surface")}));
      return Boolean(main && input && branded);
    };
    const markers = {
      shell: Boolean(document.querySelector(${selectorLiteral("shell-main")})),
      sidebar: Boolean(document.querySelector(${selectorLiteral("left-panel")})),
      composer: Boolean(document.querySelector(${selectorLiteral("composer-chrome")})),
      main: Boolean(document.querySelector(${selectorLiteral("home-route")})),
      generic: genericCodexSurface(),
    };
    const settings = Boolean(document.querySelector(${selectorLiteral("settings-panel")})) ||
      Boolean(document.querySelector(${selectorLiteral("appearance-radio")})) ||
      Boolean(document.querySelector(${stableTestidLiteral("theme-preview")}));
    return {
      markers, excludedPetSurface,
      codex: !excludedPetSurface && location.protocol === 'app:' &&
        ((markers.shell && markers.sidebar) || settings || markers.main || markers.generic),
    };
  })()`, timeoutMs);
}

export async function waitForCodexProbe(session, timeoutMs = 1800) {
  const deadline = Date.now() + timeoutMs;
  let probe = null;
  while (Date.now() < deadline) {
    try {
      probe = await probeSession(session, Math.max(1, deadline - Date.now()));
    } catch (error) {
      const transient = /execution context.*(destroyed|not found)|cannot find context|inspected target navigated/i.test(error.message);
      if (session.closed || !transient) throw error;
    }
    if (probe?.codex) return probe;
    await new Promise((resolve) => setTimeout(resolve, Math.min(50, Math.max(0, deadline - Date.now()))));
  }
  return probe;
}

export async function connectTarget(target, port) {
  return new CdpSession(target, port).open();
}

export async function listVerifiedTargets(port) {
  return listAppTargets(port);
}

export async function listTargetInventory(port) {
  return summarizeCodexTargets(await fetchTargetList(port));
}

export async function connectCodexTargets(port, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const targets = await listAppTargets(port);
      const connected = [];
      for (const target of targets) {
        let session;
        try {
          session = await connectTarget(target, port);
          const probe = await probeSession(session);
          if (probe?.codex) connected.push({ target, session, probe });
          else {
            if (probe?.excludedPetSurface && !await cleanupExcludedSurface(session)) {
              throw new Error("Excluded Pet surface cleanup did not verify");
            }
            session.close();
          }
        } catch (error) {
          session?.close();
          lastError = error;
        }
      }
      if (connected.length) return connected;
      lastError = new Error("No page matched the expected ChatGPT shell markers");
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 350));
  }
  throw new Error(`No verified ChatGPT renderer on 127.0.0.1:${port}: ${lastError?.message ?? "timed out"}`);
}
