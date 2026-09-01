// Official theme.json schema and timestamp validation.

import {
  COLOR_KEYS,
  COLOR_PATTERN,
  STUDIO_COLOR_KEYS,
  STUDIO_COPY_KEYS,
  THEME_COPY_KEYS,
  THEME_ID_PATTERN,
  THEME_REQUIRED,
  CONTROL_PATTERN,
} from "./theme-package-contract.mjs";
import {
  assertExactKeys,
  assertObject,
  assertString,
  fail,
} from "./theme-package-primitives.mjs";

export function validateTimestamp(value) {
  assertString(value, "manifest.createdAt", { min: 1, max: 40, pattern: RFC3339_PATTERN, controls: null });
  const match = RFC3339_PATTERN.exec(value);
  if (!match) fail("manifest.createdAt is not a valid date-time");

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const hour = Number(match[4]);
  const minute = Number(match[5]);
  const second = Number(match[6]);
  const offsetHour = match[9] === undefined ? 0 : Number(match[9]);
  const offsetMinute = match[10] === undefined ? 0 : Number(match[10]);
  const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const daysInMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  const calendarValid = month >= 1 && month <= 12
    && day >= 1 && day <= (daysInMonth[month - 1] ?? 0)
    && hour <= 23 && minute <= 59 && second <= 59
    && offsetHour <= 23 && offsetMinute <= 59;
  if (!calendarValid || !Number.isFinite(Date.parse(value))) {
    fail("manifest.createdAt is not a valid date-time");
  }
}

export function validateOfficialTheme(value) {
  const theme = assertObject(value, "theme.json");
  assertExactKeys(
    theme,
    THEME_REQUIRED,
    [...THEME_COPY_KEYS, "promoUrl", "appearance", "art", "colors", "studio"],
    "theme.json",
  );
  if (theme.schemaVersion !== 1) fail("theme.json must use schemaVersion 1");
  assertString(theme.id, "theme.json.id", { min: 3, max: 64, pattern: THEME_ID_PATTERN, controls: null });
  assertString(theme.name, "theme.json.name", { min: 1, max: 80 });
  assertString(theme.image, "theme.json.image", { min: 1, max: 32, controls: null });
  if (!BACKGROUND_MEDIA.has(theme.image)) fail("theme.json.image must name one registered background file");
  for (const key of THEME_COPY_KEYS) {
    if (theme[key] !== undefined) assertString(theme[key], `theme.json.${key}`, { max: 120 });
  }
  if (theme.promoUrl !== undefined) assertString(theme.promoUrl, "theme.json.promoUrl", { max: 512 });
  if (theme.appearance !== undefined && !new Set(["auto", "light", "dark"]).has(theme.appearance)) {
    fail("theme.json.appearance is unsupported");
  }
  if (theme.art !== undefined) {
    const art = assertObject(theme.art, "theme.json.art");
    assertExactKeys(art, [], ["focusX", "focusY", "safeArea", "taskMode"], "theme.json.art");
    for (const key of ["focusX", "focusY"]) {
      if (art[key] !== undefined && (typeof art[key] !== "number" || !Number.isFinite(art[key]) || art[key] < 0 || art[key] > 1)) {
        fail(`theme.json.art.${key} must be between 0 and 1`);
      }
    }
    if (art.safeArea !== undefined && !new Set(["left", "right", "none"]).has(art.safeArea)) {
      fail("theme.json.art.safeArea is unsupported");
    }
    if (art.taskMode !== undefined && !new Set(["ambient", "full", "off"]).has(art.taskMode)) {
      fail("theme.json.art.taskMode is unsupported");
    }
  }
  if (theme.colors !== undefined) {
    const colors = assertObject(theme.colors, "theme.json.colors");
    assertExactKeys(colors, COLOR_KEYS, [], "theme.json.colors");
    for (const key of COLOR_KEYS) {
      assertString(colors[key], `theme.json.colors.${key}`, {
        min: 1,
        max: 64,
        pattern: COLOR_PATTERN,
        controls: null,
      });
    }
  }
  if (theme.studio !== undefined) {
    const studio = assertObject(theme.studio, "theme.json.studio");
    assertExactKeys(studio, ["tokens", "copy", "sidebarLabels", "suggestionLabels"], [], "theme.json.studio");
    const tokens = assertObject(studio.tokens, "theme.json.studio.tokens");
    assertExactKeys(
      tokens,
      [...STUDIO_COLOR_KEYS, "sidebarWidth", "radiusSm", "radiusMd", "radiusLg", "panelOpacity", "backdropBlur", "fontScale", "density"],
      [],
      "theme.json.studio.tokens",
    );
    for (const key of STUDIO_COLOR_KEYS) {
      assertString(tokens[key], `theme.json.studio.tokens.${key}`, {
        min: 1, max: 64, pattern: COLOR_PATTERN, controls: null,
      });
    }
    for (const [key, minimum, maximum] of [
      ["sidebarWidth", 180, 320], ["radiusSm", 0, 24], ["radiusMd", 0, 32],
      ["radiusLg", 0, 48], ["panelOpacity", .4, 1], ["backdropBlur", 0, 40],
      ["fontScale", .85, 1.2],
    ]) {
      if (typeof tokens[key] !== "number" || !Number.isFinite(tokens[key]) || tokens[key] < minimum || tokens[key] > maximum) {
        fail(`theme.json.studio.tokens.${key} is out of range`);
      }
    }
    if (!new Set(["comfortable", "compact"]).has(tokens.density)) {
      fail("theme.json.studio.tokens.density is unsupported");
    }
    const copy = assertObject(studio.copy, "theme.json.studio.copy");
    assertExactKeys(copy, STUDIO_COPY_KEYS, [], "theme.json.studio.copy");
    for (const key of STUDIO_COPY_KEYS) {
      assertString(copy[key], `theme.json.studio.copy.${key}`, { max: 160 });
    }
    for (const [key, expected, maximum] of [["sidebarLabels", 5, 60], ["suggestionLabels", 4, 120]]) {
      if (!Array.isArray(studio[key]) || studio[key].length !== expected) {
        fail(`theme.json.studio.${key} must contain exactly ${expected} labels`);
      }
      studio[key].forEach((label, index) => assertString(
        label, `theme.json.studio.${key}[${index}]`, { max: maximum },
      ));
    }
  }
  return theme;
}
