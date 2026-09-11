/**
 * The Codex renderer exposes several DevTools targets at once. Keep the
 * target boundary in one place so the injector never mistakes a webview or
 * the avatar composition surface for the main application renderer.
 */

export const CODEX_TARGET_KINDS = Object.freeze([
  "codex-page",
  "excluded-surface",
  "webview",
  "external-page",
  "unsupported",
]);

function initialRouteFor(target) {
  try {
    return new URL(target?.url ?? "").searchParams.get("initialRoute") ?? "";
  } catch {
    return "";
  }
}

function pathnameFor(target) {
  try {
    return new URL(target?.url ?? "").pathname;
  } catch {
    return "";
  }
}

export function isCodexAppURL(value) {
  return typeof value === "string" && value.startsWith("app://");
}

export function isExcludedCodexSurface(target) {
  if (!isCodexAppURL(target?.url)) return false;
  const pathname = pathnameFor(target);
  const initialRoute = initialRouteFor(target);
  return pathname.endsWith("/avatar-overlay-composition-surface.html")
    || initialRoute === "/avatar-overlay"
    || initialRoute.startsWith("/avatar-overlay/");
}

export function classifyCodexTarget(target) {
  if (target?.type === "webview") return "webview";
  if (target?.type !== "page") return "unsupported";
  if (!isCodexAppURL(target.url)) return "external-page";
  if (isExcludedCodexSurface(target)) return "excluded-surface";
  return "codex-page";
}

export function isCodexPageTarget(target) {
  return classifyCodexTarget(target) === "codex-page";
}

export function summarizeCodexTargets(targets) {
  const summary = Object.fromEntries(CODEX_TARGET_KINDS.map((kind) => [kind, 0]));
  for (const target of Array.isArray(targets) ? targets : []) {
    summary[classifyCodexTarget(target)]++;
  }
  return {
    total: Array.isArray(targets) ? targets.length : 0,
    ...summary,
  };
}
