import {
  MAX_RENDERER_DIMENSION,
  MIN_RENDERER_HEIGHT,
  MIN_RENDERER_WIDTH,
  runtimeVersion,
  selectorLiteral,
  stableTestidLiteral,
} from "./config.mjs";

function hasReasonableDimensions(width, height) {
  return Number.isFinite(width) && Number.isFinite(height)
    && width >= MIN_RENDERER_WIDTH && height >= MIN_RENDERER_HEIGHT
    && width <= MAX_RENDERER_DIMENSION && height <= MAX_RENDERER_DIMENSION;
}

export function classifyNativeWindowResponse(response) {
  const windowId = Number(response?.windowId);
  const bounds = response?.bounds && typeof response.bounds === "object"
    ? {
        width: Number(response.bounds.width),
        height: Number(response.bounds.height),
        windowState: typeof response.bounds.windowState === "string"
          ? response.bounds.windowState : null,
      }
    : null;
  const stateReady = bounds && ["normal", "maximized", "fullscreen"].includes(bounds.windowState);
  const ready = Number.isSafeInteger(windowId) && windowId > 0 && stateReady
    && hasReasonableDimensions(bounds.width, bounds.height);
  return {
    status: ready ? "ready" : "not-ready",
    windowId: Number.isSafeInteger(windowId) && windowId > 0 ? windowId : null,
    bounds,
    reason: ready ? null : "native-window-not-visible",
  };
}

export function classifyNativeWindowError(error) {
  const message = error instanceof Error ? error.message : String(error ?? "");
  const cdpCode = Number(error?.cdpCode);
  const withoutCode = message.replace(/\s*\(-?\d+\)\s*$/, "").trim();
  const domainUnsupported = cdpCode === -32601
    || /\(-32601\)\s*$/.test(message)
    || /^method(?: ['"]Browser\.getWindowForTarget['"])? not found$/i.test(withoutCode)
    || /^['"]?Browser\.getWindowForTarget['"]? (?:wasn't|was not) found$/i.test(withoutCode);
  const windowNotFound = cdpCode === -32000
    || /\(-32000\)\s*$/.test(message)
    || /^browser window not found$/i.test(withoutCode);
  const unsupported = domainUnsupported || windowNotFound;
  return {
    status: unsupported ? "unsupported" : "not-ready",
    windowId: null,
    bounds: null,
    reason: domainUnsupported ? "browser-window-domain-unsupported"
      : windowNotFound ? "browser-window-not-found" : "native-window-unavailable",
  };
}

export function assessRendererVerification(renderer, nativeWindow, expected) {
  const result = renderer && typeof renderer === "object" ? { ...renderer } : {};
  const viewportWidth = Number(result.viewport?.width);
  const viewportHeight = Number(result.viewport?.height);
  const viewportPass = hasReasonableDimensions(viewportWidth, viewportHeight);
  const documentVisible = result.documentVisibility === "visible";
  const settingsRoute = result.scope?.baseState === "settings";
  const homeRoute = result.scope?.baseState === "home" || result.homeRoute || result.homePresent;
  const l1ScopePass = result.scope?.level === "L1"
    && Array.isArray(result.scope?.missingL1) && result.scope.missingL1.length === 0;
  const genericStructurePass = l1ScopePass && Boolean(result.genericMain?.visible)
    && (Boolean(result.genericInput?.visible) || Boolean(homeRoute && result.homePresent));
  const l0StructurePass = result.scope?.level === "L0"
    && settingsRoute && Boolean(result.settings?.visible);
  const structurePass = l0StructurePass || (l1ScopePass && (
    (Boolean(result.shell?.visible) && Boolean(result.sidebar?.visible)) || genericStructurePass
  ));
  const nativeWindowPass = nativeWindow?.status === "ready";
  const fallbackWindowPass = nativeWindow?.status === "unsupported";
  const windowPass = documentVisible && viewportPass && (nativeWindowPass || fallbackWindowPass);
  const basePass = result.installed && result.version === expected.skinVersion
    && result.stylePresent && result.businessClassPollution === 0
    && structurePass && windowPass && !result.documentOverflow?.x;
  const payloadPass = (!expected.expectedThemeId || result.themeId === expected.expectedThemeId)
    && (!expected.expectedRevision || result.revision === expected.expectedRevision);
  const visibleSuggestionLabels = Array.isArray(result.suggestionLabels)
    ? result.suggestionLabels.filter((item) => item?.visible) : [];
  const homeFallbackVisible = Boolean(homeRoute && result.homePresent && result.genericMain?.visible);
  const homePass = !homeRoute || (
    result.homePresent && ((result.hero?.visible && result.hero.width >= 280
      && result.hero.height >= 120) || homeFallbackVisible)
    && (result.visibleCardCount === 0 || (
      visibleSuggestionLabels.length >= result.visibleCardCount
      && result.suggestionLabelColorsMatch
    ))
  );
  result.nativeWindow = nativeWindow;
  result.checks = {
    documentVisible,
    fallbackWindowPass,
    nativeWindowPass,
    payloadPass,
    structurePass,
    viewportPass,
    windowPass,
  };
  result.pass = Boolean(basePass && homePass && payloadPass);
  result.expectedThemeId = expected.expectedThemeId;
  result.expectedRevision = expected.expectedRevision;
  result.softNotes = {
    projectButtonOptional: !result.projectButton?.visible,
    composerOptionalOnNonTaskRoutes: !result.composer?.visible,
    suggestionCardsOptional: homeRoute && result.visibleCardCount === 0,
  };
  return result;
}

export async function removeFromSession(session) {
  return session.evaluate(`(() => {
    window.__CODEX_DREAM_SKIN_DISABLED__ = true;
    const state = window.__CODEX_DREAM_SKIN_STATE__;
    let cleaned = false;
    try { cleaned = Boolean(state?.cleanup && state.cleanup()); } catch {}
    if (cleaned) return true;
    const root = document.documentElement;
    for (const attribute of [...(root?.attributes || [])]) {
      if (attribute.name.startsWith('data-dream-')) root.removeAttribute(attribute.name);
    }
    for (const property of [...(root?.style || [])]) {
      if (property.startsWith('--dream-') || property.startsWith('--ds-')) root.style.removeProperty(property);
    }
    for (const node of document.querySelectorAll('[data-ds-part]')) node.removeAttribute('data-ds-part');
    const sheets = window.__CODEX_DREAM_SKIN_STYLE_SHEETS__;
    if (sheets && 'adoptedStyleSheets' in document) {
      document.adoptedStyleSheets = [...document.adoptedStyleSheets].filter((sheet) => !sheets.has(sheet));
    }
    delete window.__CODEX_DREAM_SKIN_STYLE_SHEETS__;
    try { if (state?.artUrl) URL.revokeObjectURL(state.artUrl); } catch {}
    document.getElementById('codex-dream-skin-style')?.remove();
    delete window.__CODEX_DREAM_SKIN_STATE__;
    return true;
  })()`);
}

export async function verifyRemovedSession(session) {
  return session.evaluate(`(() => {
    const root = document.documentElement;
    const hasAttributes = [...root.attributes].some((attribute) => attribute.name.startsWith('data-dream-'));
    const hasVariables = [...root.style].some((property) => property.startsWith('--dream-') || property.startsWith('--ds-'));
    const hasParts = Boolean(document.querySelector('[data-ds-part]'));
    const sheets = window.__CODEX_DREAM_SKIN_STYLE_SHEETS__;
    const hasSheets = Boolean(sheets?.size && 'adoptedStyleSheets' in document &&
      [...document.adoptedStyleSheets].some((sheet) => sheets.has(sheet)));
    return !hasAttributes && !hasVariables && !hasParts && !hasSheets &&
      !document.getElementById('codex-dream-skin-style') && !window.__CODEX_DREAM_SKIN_STATE__;
  })()`);
}

export async function cleanupExcludedSurface(session) {
  if (!await removeFromSession(session)) return false;
  return verifyRemovedSession(session);
}

export async function inspectNativeWindow(session) {
  try {
    const response = await session.send(
      "Browser.getWindowForTarget",
      { targetId: session.target.id },
      1500,
    );
    return classifyNativeWindowResponse(response);
  } catch (error) {
    return classifyNativeWindowError(error);
  }
}

export async function verifySession(session, expectedThemeId = null, expectedRevision = null) {
  const renderer = await session.evaluate(`(() => {
    const box = (node) => {
      if (!node) return null;
      const r = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      const opacity = Number.parseFloat(style.opacity);
      const right = Number.isFinite(r.right) ? r.right : r.x + r.width;
      const bottom = Number.isFinite(r.bottom) ? r.bottom : r.y + r.height;
      let cssVisible = r.width > 0 && r.height > 0 && style.display !== 'none' &&
        style.visibility !== 'hidden' && style.visibility !== 'collapse' &&
        style.contentVisibility !== 'hidden' && (!Number.isFinite(opacity) || opacity > 0);
      try {
        if (typeof node.checkVisibility === 'function') cssVisible = cssVisible && node.checkVisibility({
          checkOpacity: true, checkVisibilityCSS: true,
        });
      } catch {}
      const intersectsViewport = right > 0 && bottom > 0 && r.x < innerWidth && r.y < innerHeight;
      return {
        x: Math.round(r.x), y: Math.round(r.y), width: Math.round(r.width), height: Math.round(r.height),
        visible: Boolean(node.isConnected !== false && cssVisible && intersectsViewport),
      };
    };
    const homeIndicator = document.querySelector(${selectorLiteral("home-icon")});
    const homeSignal = homeIndicator ?? document.querySelector(${selectorLiteral("game-source")}) ??
      document.querySelector(${selectorLiteral("home-suggestions")});
    const homeRoute = homeSignal?.closest('[role="main"]') ?? null;
    const home = document.querySelector(${selectorLiteral("home-route")}) ?? homeRoute;
    const suggestions = home?.querySelector(${selectorLiteral("home-suggestions")}) ?? null;
    const cardButtons = suggestions ? [...suggestions.querySelectorAll('button')] : [];
    const cardBoxes = cardButtons.map(box);
    const visibleCards = cardBoxes.filter((item) => item?.visible);
    const suggestionLabels = cardButtons.flatMap((button) => {
      const expectedColor = getComputedStyle(button).color;
      return [...button.querySelectorAll('*')]
        .filter((node) => [...node.childNodes].some((child) => child.nodeType === 3 && child.textContent.trim()))
        .map((node) => ({
          ...box(node), text: node.textContent.trim().slice(0, 80),
          color: getComputedStyle(node).color, expectedColor,
        }));
    });
    const visibleSuggestionLabels = suggestionLabels.filter((item) => item?.visible);
    const suggestionLabelColorsMatch = visibleSuggestionLabels.every((item) => item.color === item.expectedColor);
    const homeChildren = home?.children ? Array.from(home.children) : [];
    const bannerHolder = homeChildren.find((el) => el.querySelector(${selectorLiteral("home-banners")}));
    const siblingCandidates = homeChildren.filter((el) => el !== bannerHolder).map(box);
    const heroChain = [];
    for (let node = home?.firstElementChild ?? null; node && heroChain.length < 3; node = node.firstElementChild) {
      heroChain.push(node);
    }
    const boxableChain = heroChain.filter((node) => typeof node?.getBoundingClientRect === 'function');
    const chainCandidates = boxableChain.map(box);
    const hero = siblingCandidates.find((item) => item?.visible && item.width >= 280 && item.height >= 120)
      ?? chainCandidates.findLast((item) => item?.visible)
      ?? siblingCandidates.find((item) => item?.visible)
      ?? box(boxableChain[boxableChain.length - 1]);
    const projectButton = box(home?.querySelector(${selectorLiteral("project-selector")} + " > button"));
    const shell = box(document.querySelector(${selectorLiteral("shell-main")}));
    const composer = box(document.querySelector(${selectorLiteral("composer-chrome")}));
    const sidebar = box(document.querySelector(${selectorLiteral("left-panel")}));
    const genericMain = box(document.querySelector('[data-ds-part="main"], [data-ds-part="home"]'));
    const genericInput = box(document.querySelector('[data-ds-part="composer"]'));
    const settingsBoxes = [
      box(document.querySelector(${selectorLiteral("settings-panel")})),
      box(document.querySelector(${selectorLiteral("appearance-radio")})),
      box(document.querySelector(${stableTestidLiteral("theme-preview")})),
    ];
    const settings = settingsBoxes.find((item) => item?.visible) ?? settingsBoxes.find(Boolean) ?? null;
    const runtime = window.__CODEX_DREAM_SKIN_STATE__;
    const adopted = runtime?.styleMode === 'adopted' && [...document.adoptedStyleSheets].includes(runtime.styleSheet);
    const fallback = runtime?.styleMode === 'style' && document.getElementById('codex-dream-skin-style') === runtime.styleNode;
    return {
      installed: document.documentElement.getAttribute('data-dream-skin') === 'active',
      documentVisibility: document.visibilityState,
      version: runtime?.version ?? null, themeId: runtime?.themeId ?? null,
      revision: runtime?.revision ?? null, styleMode: runtime?.styleMode ?? null,
      stylePresent: Boolean(adopted || fallback), scope: runtime?.scope ?? null,
      businessClassPollution: [...document.querySelectorAll('[class]')].filter((node) =>
        [...node.classList].some((name) => /^(?:dream-|codex-dream-skin(?:-|$))/.test(name))).length,
      homeRoute: Boolean(homeRoute), homePresent: Boolean(home), hero, cards: cardBoxes,
      visibleCardCount: visibleCards.length, suggestionLabels, suggestionLabelColorsMatch,
      projectButton, shell, composer, sidebar, genericMain, genericInput, settings,
      viewport: { width: innerWidth, height: innerHeight },
      documentOverflow: {
        x: document.documentElement.scrollWidth > document.documentElement.clientWidth,
        y: document.documentElement.scrollHeight > document.documentElement.clientHeight,
      },
    };
  })()`);
  const nativeWindow = await inspectNativeWindow(session);
  return assessRendererVerification(renderer, nativeWindow, {
    skinVersion: runtimeVersion,
    expectedThemeId,
    expectedRevision,
  });
}

export async function waitForVerifiedSession(
  session,
  timeoutMs,
  expectedThemeId = null,
  expectedRevision = null,
  retryDelayMs = 500,
) {
  const deadline = Date.now() + timeoutMs;
  const retryDelay = Number.isFinite(retryDelayMs) && retryDelayMs >= 0 ? retryDelayMs : 500;
  let lastResult;
  let lastError;
  while (Date.now() < deadline) {
    try {
      lastResult = await verifySession(session, expectedThemeId, expectedRevision);
      lastError = null;
      if (lastResult.pass) return lastResult;
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, retryDelay));
  }
  if (!lastResult && lastError) throw lastError;
  return lastResult;
}
