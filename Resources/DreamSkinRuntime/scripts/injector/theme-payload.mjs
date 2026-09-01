import fs from "node:fs/promises";
import { constants as fsConstants } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";
import { Script } from "node:vm";
import { readImageMetadata } from "../image-metadata.mjs";
import {
  assetsRoot,
  MAX_ART_BYTES,
  MAX_SAFE_CSS_BYTES,
  runtimeVersion,
  selectorLiteral,
  stableTestidLiteral,
} from "./config.mjs";
import {
  normalizeThemeColor,
  normalizeThemeText,
} from "../../assets/theme-package-validator.mjs";
import { decodeAndValidateSafeCss } from "../../assets/safe-css-validator.mjs";

let staticPayloadAssets = null;
const STATIC_CSS_FILES = [
  "dream-skin.css",
  "dream-skin/tokens.css",
  "dream-skin/shell.css",
  "dream-skin/home.css",
  "dream-skin/composer.css",
  "dream-skin/task.css",
  "dream-skin/controls.css",
  "dream-skin/accessibility.css",
];
const STATIC_RENDERER_FILES = [
  "renderer/bootstrap.js",
  "renderer/palette.js",
  "renderer/art-analysis.js",
  "renderer/style.js",
  "renderer/parts.js",
  "renderer/scope.js",
  "renderer/cleanup.js",
  "renderer/lifecycle.js",
];

function assertContainedPath(rootPath, candidatePath, label) {
  const relative = path.relative(rootPath, candidatePath);
  if (
    relative === ""
    || (!path.isAbsolute(relative) && relative !== ".." && !relative.startsWith(`..${path.sep}`))
  ) return;
  throw new Error(`${label} must stay inside its theme directory`);
}

function sameFileStat(left, right) {
  return left.isFile() && right.isFile()
    && left.dev === right.dev
    && left.ino === right.ino
    && left.size === right.size
    && left.mtimeMs === right.mtimeMs
    && left.ctimeMs === right.ctimeMs;
}

async function loadSafeCss(directory) {
  const cssPath = path.join(directory, "theme.css");
  let handle;
  try {
    handle = await fs.open(cssPath, fsConstants.O_RDONLY | (fsConstants.O_NOFOLLOW ?? 0));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    if (error.code === "ELOOP") throw new Error("Theme Safe CSS must not be a symbolic link");
    throw error;
  }
  try {
    const before = await handle.stat();
    if (!before.isFile() || before.size < 1 || before.size > MAX_SAFE_CSS_BYTES) {
      throw new Error(`Theme Safe CSS must be a non-empty file no larger than ${MAX_SAFE_CSS_BYTES} bytes`);
    }
    const bytes = await handle.readFile();
    const after = await handle.stat();
    if (!sameFileStat(before, after) || bytes.length !== after.size) {
      throw new Error("Theme Safe CSS changed while being loaded");
    }
    const { source, runtimeSource, validation } = decodeAndValidateSafeCss(bytes);
    return { path: cssPath, runtimeSource, source, stat: after, validation };
  } finally {
    await handle.close();
  }
}

function readChoice(value, name, choices, configPath) {
  if (value === undefined) return undefined;
  if (typeof value !== "string" || !choices.includes(value)) {
    throw new Error(`${configPath} has an invalid ${name} field`);
  }
  return value;
}

function readUnit(value, name, configPath) {
  if (value === undefined) return undefined;
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1) {
    throw new Error(`${configPath} has an invalid ${name} field`);
  }
  return value;
}

function readStudioColor(value, name, configPath) {
  const normalized = normalizeThemeColor(value, null);
  if (!normalized) throw new Error(`${configPath} has an invalid studio.tokens.${name} field`);
  return normalized;
}

function readStudioNumber(value, name, minimum, maximum, configPath) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < minimum || value > maximum) {
    throw new Error(`${configPath} has an invalid studio.tokens.${name} field`);
  }
  return value;
}

function readStudioLabels(value, name, expected, maximum, configPath) {
  if (!Array.isArray(value) || value.length !== expected) {
    throw new Error(`${configPath} has an invalid studio.${name} field`);
  }
  return value.map((item, index) => normalizeThemeText(
    item, "", maximum, `studio.${name}[${index}]`, configPath,
  ));
}

function readStudio(rawStudio, configPath) {
  if (rawStudio === undefined) return null;
  if (!rawStudio || typeof rawStudio !== "object" || Array.isArray(rawStudio)) {
    throw new Error(`${configPath} has an invalid studio field`);
  }
  const rawTokens = rawStudio.tokens && typeof rawStudio.tokens === "object"
    && !Array.isArray(rawStudio.tokens) ? rawStudio.tokens : null;
  if (!rawTokens) throw new Error(`${configPath} has an invalid studio.tokens field`);

  const tokens = {};
  for (const name of [
    "appBackground", "sidebarBackground", "surface", "surfaceElevated", "surfaceHover",
    "surfaceSelected", "border", "text", "textMuted", "textFaint", "accent", "accentHover",
    "accentContrast", "userBubble", "assistantBubble", "toolBubble", "codeBackground",
    "composerBackground", "composerBorder", "danger",
  ]) tokens[name] = readStudioColor(rawTokens[name], name, configPath);
  for (const [name, minimum, maximum] of [
    ["sidebarWidth", 180, 320], ["radiusSm", 0, 24], ["radiusMd", 0, 32],
    ["radiusLg", 0, 48], ["panelOpacity", .4, 1], ["backdropBlur", 0, 40],
    ["fontScale", .85, 1.2],
  ]) tokens[name] = readStudioNumber(rawTokens[name], name, minimum, maximum, configPath);
  tokens.density = readChoice(rawTokens.density, "studio.tokens.density", ["comfortable", "compact"], configPath);
  if (!tokens.density) throw new Error(`${configPath} has an invalid studio.tokens.density field`);

  const rawCopy = rawStudio.copy && typeof rawStudio.copy === "object"
    && !Array.isArray(rawStudio.copy) ? rawStudio.copy : null;
  if (!rawCopy) throw new Error(`${configPath} has an invalid studio.copy field`);
  const copy = Object.fromEntries([
    ["brandSubtitle", 80], ["tagline", 160], ["projectPrefix", 80], ["projectLabel", 80],
    ["statusText", 80], ["quote", 80], ["userLabel", 40], ["assistantLabel", 40],
    ["toolLabel", 80], ["codeLabel", 80],
  ].map(([name, maximum]) => [name, normalizeThemeText(
    rawCopy[name], "", maximum, `studio.copy.${name}`, configPath,
  )]));
  return {
    tokens,
    copy,
    sidebarLabels: readStudioLabels(rawStudio.sidebarLabels, "sidebarLabels", 5, 60, configPath),
    suggestionLabels: readStudioLabels(rawStudio.suggestionLabels, "suggestionLabels", 4, 120, configPath),
  };
}

function normalizeTheme(raw, configPath) {
  if (raw.schemaVersion !== 1 || typeof raw.image !== "string" || !raw.image) {
    throw new Error(`${configPath} has an unsupported schema or image field`);
  }
  if (/[\u0000-\u001f\u007f-\u009f\u2028\u2029]/u.test(raw.image)) {
    throw new Error(`${configPath} has an invalid image field`);
  }
  if (path.basename(raw.image) !== raw.image) {
    throw new Error("Theme image must stay inside its theme directory");
  }
  const rawColors = raw.colors && typeof raw.colors === "object" && !Array.isArray(raw.colors)
    ? raw.colors : null;
  const colorKeys = [
    "background", "panel", "panelAlt", "accent", "accentAlt", "secondary",
    "highlight", "text", "muted", "line",
  ];
  const appearance = readChoice(raw.appearance, "appearance", ["auto", "light", "dark"], configPath);
  if (raw.art !== undefined && (!raw.art || typeof raw.art !== "object" || Array.isArray(raw.art))) {
    throw new Error(`${configPath} has an invalid art field`);
  }
  const rawArt = raw.art || {};
  const art = {
    focusX: readUnit(rawArt.focusX, "art.focusX", configPath),
    focusY: readUnit(rawArt.focusY, "art.focusY", configPath),
    safeArea: readChoice(rawArt.safeArea, "art.safeArea", ["auto", "left", "right", "center", "none"], configPath),
    taskMode: readChoice(rawArt.taskMode, "art.taskMode", ["auto", "ambient", "banner", "full", "off"], configPath),
  };
  const theme = {
    schemaVersion: 1,
    id: normalizeThemeText(raw.id, "custom", 80, "id", configPath),
    name: normalizeThemeText(raw.name, "Codex Dream Skin", 80, "name", configPath),
    brandSubtitle: normalizeThemeText(raw.brandSubtitle, "CODEX DREAM SKIN", 120, "brandSubtitle", configPath),
    tagline: normalizeThemeText(raw.tagline, "Make something wonderful.", 120, "tagline", configPath),
    projectPrefix: normalizeThemeText(raw.projectPrefix, "Choose project · ", 120, "projectPrefix", configPath),
    projectLabel: normalizeThemeText(raw.projectLabel, "◉  Choose project", 120, "projectLabel", configPath),
    statusText: normalizeThemeText(raw.statusText, "DREAM SKIN ONLINE", 120, "statusText", configPath),
    quote: normalizeThemeText(raw.quote, "MAKE SOMETHING WONDERFUL", 120, "quote", configPath),
    image: raw.image,
    studio: readStudio(raw.studio, configPath),
    colorMode: rawColors ? "explicit" : "auto",
    explicitColorKeys: rawColors ? colorKeys.filter((key) => Object.hasOwn(rawColors, key)) : [],
    colors: {
      background: normalizeThemeColor(rawColors?.background, "#071116"),
      panel: normalizeThemeColor(rawColors?.panel, "#0b1a20"),
      panelAlt: normalizeThemeColor(rawColors?.panelAlt, "#10272c"),
      accent: normalizeThemeColor(rawColors?.accent, "#7cff46"),
      accentAlt: normalizeThemeColor(rawColors?.accentAlt, "#b8ff3d"),
      secondary: normalizeThemeColor(rawColors?.secondary, "#36d7e8"),
      highlight: normalizeThemeColor(rawColors?.highlight, "#642a8c"),
      text: normalizeThemeColor(rawColors?.text, "#e9fff1"),
      muted: normalizeThemeColor(rawColors?.muted, "#9ebdb3"),
      line: normalizeThemeColor(rawColors?.line, "rgba(124, 255, 70, .28)"),
    },
  };
  if (appearance !== undefined) theme.appearance = appearance;
  if (Object.values(art).some((value) => value !== undefined)) {
    theme.art = Object.fromEntries(Object.entries(art).filter(([, value]) => value !== undefined));
  }
  return theme;
}

export async function loadTheme(themeDir) {
  const requestedRoot = themeDir ?? assetsRoot;
  const configPath = path.join(requestedRoot, "theme.json");
  let themeRoot;
  let canonicalConfigPath;
  try {
    [themeRoot, canonicalConfigPath] = await Promise.all([
      fs.realpath(requestedRoot),
      fs.realpath(configPath),
    ]);
  } catch (error) {
    if (themeDir && error.code === "ENOENT") {
      throw new Error(`Explicit theme directory is missing theme.json: ${configPath}`);
    }
    throw error;
  }
  assertContainedPath(themeRoot, canonicalConfigPath, "Theme config");
  let config;
  try {
    config = await fs.readFile(canonicalConfigPath, "utf8");
  } catch (error) {
    if (themeDir && error.code === "ENOENT") {
      throw new Error(`Explicit theme directory is missing theme.json: ${configPath}`);
    }
    throw error;
  }
  const theme = normalizeTheme(JSON.parse(config), configPath);
  const requestedImagePath = path.join(themeRoot, theme.image);
  let imagePath;
  try {
    imagePath = await fs.realpath(requestedImagePath);
  } catch (error) {
    if (error.code === "ENOENT") throw new Error(`Theme image is missing: ${requestedImagePath}`);
    throw error;
  }
  assertContainedPath(themeRoot, imagePath, "Theme image");
  const imageStat = await fs.stat(imagePath);
  const extension = path.extname(theme.image).toLowerCase();
  if (![".png", ".jpg", ".jpeg", ".webp"].includes(extension)) {
    throw new Error(`Unsupported theme image format: ${extension || "missing"}`);
  }
  let imageHandle;
  try {
    imageHandle = await fs.open(imagePath, fsConstants.O_RDONLY | (fsConstants.O_NOFOLLOW ?? 0));
  } catch (error) {
    if (error.code === "ELOOP") throw new Error("Theme image changed into a symbolic link while loading");
    throw error;
  }
  try {
    const openedStat = await imageHandle.stat();
    if (!imageStat.isFile() || !openedStat.isFile()
      || imageStat.dev !== openedStat.dev || imageStat.ino !== openedStat.ino
      || openedStat.size < 1 || openedStat.size > MAX_ART_BYTES) {
      throw new Error(`Theme image must be a stable non-empty file no larger than ${MAX_ART_BYTES} bytes`);
    }
    const art = await imageHandle.readFile();
    if (art.length < 1 || art.length > MAX_ART_BYTES) {
      throw new Error(`Theme image must be a non-empty file no larger than ${MAX_ART_BYTES} bytes`);
    }
    const safeCss = await loadSafeCss(themeRoot);
    return {
      art,
      assetsRoot: themeRoot,
      extension,
      imagePath,
      safeCss: safeCss?.source ?? "",
      safeCssRuntime: safeCss?.runtimeSource ?? "",
      safeCssPath: safeCss?.path ?? null,
      safeCssStatus: safeCss ? "validated" : "none",
      theme,
    };
  } finally {
    await imageHandle.close();
  }
}

async function loadStaticPayloadAssets() {
  const cacheHit = Boolean(staticPayloadAssets);
  if (!staticPayloadAssets) {
    staticPayloadAssets = Promise.all([
      Promise.all(STATIC_CSS_FILES.map((file) => fs.readFile(path.join(assetsRoot, file), "utf8")))
        .then((parts) => parts.join("\n")),
      fs.readFile(path.join(assetsRoot, "renderer-inject.js"), "utf8"),
      Promise.all(STATIC_RENDERER_FILES.map((file) => fs.readFile(path.join(assetsRoot, file), "utf8")))
        .then((parts) => parts.join("\n")),
    ]).then(([css, template, rendererCode]) => {
      const composedTemplate = template.replace("__DREAM_SKIN_RENDERER_CODE__", () => rendererCode);
      if (composedTemplate === template) throw new Error("Renderer module placeholder is missing");
      return [css, composedTemplate];
    }).catch((error) => {
      staticPayloadAssets = null;
      throw error;
    });
  }
  const [css, template] = await staticPayloadAssets;
  return { css, template, cacheHit };
}

export function invalidateStaticPayloadAssets() {
  staticPayloadAssets = null;
}

export async function loadPayload(themeDir) {
  const startedAt = performance.now();
  const [staticAssets, loaded] = await Promise.all([
    loadStaticPayloadAssets(),
    loadTheme(themeDir),
  ]);
  const { css, template } = staticAssets;
  const { art, extension, safeCssRuntime, safeCssStatus, theme } = loaded;
  const combinedCss = safeCssRuntime ? `${css}\n${safeCssRuntime}\n` : css;
  const styleRevision = createHash("sha256").update(combinedCss).digest("hex").slice(0, 20);
  const artMetadata = readImageMetadata(art, extension);
  if (!artMetadata) throw new Error("Theme image metadata is invalid or exceeds the 16384px / 50MP safety limit");
  const artKey = createHash("sha256").update(art).digest("hex").slice(0, 20);
  theme.artMetadata = artMetadata;
  theme.artKey = artKey;
  const mime = extension === ".jpg" || extension === ".jpeg" ? "image/jpeg"
    : extension === ".webp" ? "image/webp" : "image/png";
  const artDataUrl = `data:${mime};base64,${art.toString("base64")}`;
  const revision = createHash("sha256")
    .update(runtimeVersion)
    .update(combinedCss)
    .update(template)
    .update(JSON.stringify(theme))
    .digest("hex")
    .slice(0, 20);
  const payload = template
    .replace("__DREAM_SKIN_CSS_JSON__", () => JSON.stringify(combinedCss))
    .replace("__DREAM_SKIN_ART_JSON__", () => JSON.stringify(artDataUrl))
    .replace("__DREAM_SKIN_THEME_JSON__", () => JSON.stringify(theme))
    .replace("__DREAM_SKIN_VERSION_JSON__", () => JSON.stringify(runtimeVersion))
    .replace("__DREAM_SKIN_STYLE_REVISION_JSON__", () => JSON.stringify(styleRevision))
    .replace("__DREAM_SKIN_PAYLOAD_REVISION_JSON__", () => JSON.stringify(revision));
  assertPayloadIntegrity(payload);
  return {
    imageBytes: art.length,
    payload,
    revision,
    safeCssStatus,
    theme,
    timings: {
      buildMs: Number((performance.now() - startedAt).toFixed(3)),
      staticCacheHit: staticAssets.cacheHit,
    },
  };
}

export function assertPayloadIntegrity(payload) {
  if (/__DREAM_SKIN_[A-Z0-9_]+_JSON__/.test(payload)) {
    throw new Error("Payload placeholders were not fully replaced");
  }
  try {
    new Script(payload, { filename: "dream-skin-payload.js" });
  } catch (error) {
    throw new Error(`Payload is not a parsable renderer script: ${error.message}`);
  }
  return true;
}

export function earlyPayloadFor(payload, revision) {
  return `(() => {
    const generationKey = "__CODEX_DREAM_SKIN_EARLY_GENERATION__";
    const appliedKey = "__CODEX_DREAM_SKIN_EARLY_APPLIED__";
    const generation = ${JSON.stringify(revision)};
    window[generationKey] = generation;
    let bootstrapTimer = null;
    let timeout = null;
    const stop = () => {
      if (bootstrapTimer) clearInterval(bootstrapTimer);
      bootstrapTimer = null;
      if (timeout) clearTimeout(timeout);
      timeout = null;
    };
    const hasCodexSurface = () => {
      if (location.protocol !== "app:") return false;
      const shell = document.querySelector(${selectorLiteral("shell-main")});
      const sidebar = document.querySelector(${selectorLiteral("left-panel")});
      const main = document.querySelector(${selectorLiteral("home-route")});
      const settings = document.querySelector(${selectorLiteral("settings-panel")}) ||
        document.querySelector(${selectorLiteral("appearance-radio")}) ||
        document.querySelector(${stableTestidLiteral("theme-preview")});
      const genericMain = document.querySelector('main, [role="main"]');
      const genericInput = document.querySelector('textarea, [contenteditable="true"], [role="textbox"]');
      const branded = Boolean(document.querySelector(
        ${stableTestidLiteral("app-shell-header-context-menu-surface")},
      ));
      return Boolean((shell && sidebar) || settings || main ||
        (genericMain && genericInput && branded));
    };
    const install = () => {
      if (window[generationKey] !== generation) { stop(); return true; }
      if (!document.documentElement || !hasCodexSurface()) return false;
      stop();
      ${payload};
      window[appliedKey] = generation;
      return true;
    };
    if (install()) return;
    document.addEventListener?.("DOMContentLoaded", install, { once: true });
    bootstrapTimer = setInterval(install, 250);
    timeout = setTimeout(stop, 10000);
  })()`;
}
