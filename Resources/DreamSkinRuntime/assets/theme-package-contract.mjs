// Registered theme-package limits, schema keys, and format patterns.

import { constants as fsConstants } from "node:fs";

export const LIMITS = Object.freeze({
  manifest: 65_536,
  theme: 65_536,
  simpleTheme: 1_048_576,
  css: 262_144,
  image: 10_485_760,
  license: 65_536,
  signature: 4_096,
});

export const BACKGROUND_MEDIA = new Map([
  ["background.webp", "image/webp"],
  ["background.jpg", "image/jpeg"],
  ["background.png", "image/png"],
]);
export const PAYLOAD_MEDIA = new Map([
  ["theme.json", "application/json"],
  ...BACKGROUND_MEDIA,
  ["theme.css", "text/css"],
  ["LICENSE.txt", "text/plain"],
]);
export const PACKAGE_FILES = new Set([
  "manifest.json",
  "manifest.sig",
  ...PAYLOAD_MEDIA.keys(),
]);
export const MANIFEST_REQUIRED = [
  "packageVersion",
  "themeId",
  "version",
  "skinApiVersion",
  "minClientVersion",
  "platforms",
  "capabilities",
  "publisher",
  "license",
  "provenance",
  "files",
  "createdAt",
];
export const THEME_REQUIRED = ["schemaVersion", "id", "name", "image"];
export const THEME_COPY_KEYS = [
  "brandSubtitle",
  "tagline",
  "projectPrefix",
  "projectLabel",
  "statusText",
  "quote",
  "promoTitle",
  "promoSub",
];
export const COLOR_KEYS = [
  "background",
  "panel",
  "panelAlt",
  "accent",
  "accentAlt",
  "secondary",
  "highlight",
  "text",
  "muted",
  "line",
];
export const STUDIO_COLOR_KEYS = [
  "appBackground", "sidebarBackground", "surface", "surfaceElevated", "surfaceHover",
  "surfaceSelected", "border", "text", "textMuted", "textFaint", "accent", "accentHover",
  "accentContrast", "userBubble", "assistantBubble", "toolBubble", "codeBackground",
  "composerBackground", "composerBorder", "danger",
];
export const STUDIO_COPY_KEYS = [
  "brandSubtitle", "tagline", "projectPrefix", "projectLabel", "statusText", "quote",
  "userLabel", "assistantLabel", "toolLabel", "codeLabel",
];
export const SEMVER_PATTERN = /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/;
export const THEME_ID_PATTERN = /^[a-z0-9]+(?:[.-][a-z0-9]+)*$/;
export const PUBLISHER_ID_PATTERN = /^[A-Za-z0-9_-]+$/;
export const LICENSE_PATTERN = /^[A-Za-z0-9][A-Za-z0-9 .+()-]*$/;
export const KEY_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
export const CONTROL_PATTERN = /[\u0000-\u001f\u007f]/u;
export const PROVENANCE_CONTROL_PATTERN = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/u;
export const COLOR_PATTERN = /^(#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?|#[0-9a-fA-F]{3,4}|rgb\(\s*[0-9]{1,3}\s*,\s*[0-9]{1,3}\s*,\s*[0-9]{1,3}\s*\)|rgba\(\s*[0-9]{1,3}\s*,\s*[0-9]{1,3}\s*,\s*[0-9]{1,3}\s*,\s*(0|1|1\.0|0?\.[0-9]{1,6})\s*\))$/;
export const RFC3339_PATTERN = /^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.([0-9]{1,9}))?(?:Z|([+-])([0-9]{2}):([0-9]{2}))$/;
export const OPEN_FLAGS = fsConstants.O_RDONLY | (fsConstants.O_NOFOLLOW ?? 0);
export const decoder = new TextDecoder("utf-8", { fatal: true });
