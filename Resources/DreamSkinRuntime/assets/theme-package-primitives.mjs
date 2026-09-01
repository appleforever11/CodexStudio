// Shared package argument, text, JSON, and stable-file primitives.

import fs from "node:fs/promises";
import path from "node:path";
import {
  CONTROL_PATTERN,
  COLOR_PATTERN,
  LIMITS,
  OPEN_FLAGS,
  decoder,
} from "./theme-package-contract.mjs";

export function fail(message) {
  throw new Error(message);
}

export function parseArguments(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 2) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (!flag?.startsWith("--") || value === undefined) fail(`Unknown argument: ${flag ?? "<missing>"}`);
    const key = flag.slice(2);
    if (!new Set(["source", "stage", "platform", "client-version"]).has(key) || values[key]) {
      fail(`Unknown or repeated argument: ${flag}`);
    }
    values[key] = value;
  }
  for (const key of ["source", "stage", "platform", "client-version"]) {
    if (!values[key]) fail(`Missing --${key}`);
  }
  if (!new Set(["macos", "windows"]).has(values.platform)) {
    fail(`Unsupported platform: ${values.platform}`);
  }
  return values;
}

export function isObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export function assertObject(value, label) {
  if (!isObject(value)) fail(`${label} must be an object`);
  return value;
}

export function assertExactKeys(value, required, optional, label) {
  const allowed = new Set([...required, ...optional]);
  for (const key of required) {
    if (!Object.hasOwn(value, key)) fail(`${label} is missing ${key}`);
  }
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) fail(`${label} contains unsupported field ${key}`);
  }
}

export function codePointLength(value) {
  return Array.from(value).length;
}

export function normalizeThemeText(value, fallback, maxCodePoints, name, sourceLabel) {
  if (value === undefined) return fallback;
  if (
    typeof value !== "string"
    || CONTROL_PATTERN.test(value)
    || codePointLength(value) > maxCodePoints
  ) {
    throw new Error(`${sourceLabel} has an invalid ${name} field`);
  }
  return value.trim() || fallback;
}

export function normalizeThemeColor(value, fallback) {
  if (typeof value !== "string") return fallback;
  const normalized = value.trim();
  return COLOR_PATTERN.test(normalized) ? normalized : fallback;
}

export function assertString(value, label, { min = 0, max, pattern, controls = CONTROL_PATTERN } = {}) {
  if (typeof value !== "string") fail(`${label} must be a string`);
  const length = codePointLength(value);
  if (length < min || (max !== undefined && length > max)) fail(`${label} has an invalid length`);
  if (controls?.test(value)) fail(`${label} contains control characters`);
  if (pattern && !pattern.test(value)) fail(`${label} has an invalid format`);
  return value;
}

export function parseSemver(value, label) {
  assertString(value, label, { min: 1, max: 32, pattern: SEMVER_PATTERN, controls: null });
  return value.split(".").map((part) => BigInt(part));
}

export function compareSemver(left, right) {
  for (let index = 0; index < 3; index += 1) {
    if (left[index] > right[index]) return 1;
    if (left[index] < right[index]) return -1;
  }
  return 0;
}

export function assertStringSet(value, label, { min, max, allowed }) {
  if (!Array.isArray(value) || value.length < min || value.length > max) {
    fail(`${label} must contain between ${min} and ${max} values`);
  }
  const seen = new Set();
  for (const item of value) {
    if (typeof item !== "string" || !allowed.has(item)) fail(`${label} contains an unsupported value`);
    if (seen.has(item)) fail(`${label} repeats ${item}`);
    seen.add(item);
  }
  return seen;
}

export function decodeJson(bytes, label) {
  let text;
  try {
    text = decoder.decode(bytes);
  } catch {
    fail(`${label} is not valid UTF-8`);
  }
  if (text.includes("\0")) fail(`${label} contains NUL characters`);
  try {
    return JSON.parse(text);
  } catch {
    fail(`${label} is not valid JSON`);
  }
}

export function expectedLimit(name, simple = false) {
  if (name === "manifest.json") return LIMITS.manifest;
  if (name === "theme.json") return simple ? LIMITS.simpleTheme : LIMITS.theme;
  if (name === "theme.css") return LIMITS.css;
  if (name === "LICENSE.txt") return LIMITS.license;
  if (name === "manifest.sig") return LIMITS.signature;
  if (BACKGROUND_MEDIA.has(name) || /\.(?:png|jpe?g|webp)$/i.test(name)) return LIMITS.image;
  return 0;
}

export function sameFileStat(left, right) {
  return left.isFile() && right.isFile()
    && left.dev === right.dev
    && left.ino === right.ino
    && left.size === right.size
    && left.mtimeMs === right.mtimeMs
    && left.ctimeMs === right.ctimeMs;
}

export async function readStableFile(root, name, maxBytes) {
  if (path.basename(name) !== name || maxBytes < 1) fail(`Unsafe package file name: ${name}`);
  const filePath = path.join(root, name);
  let handle;
  try {
    handle = await fs.open(filePath, OPEN_FLAGS);
  } catch (error) {
    if (error.code === "ELOOP") fail(`${name} must not be a symbolic link`);
    throw error;
  }
  try {
    const before = await handle.stat();
    if (!before.isFile() || before.size < 1 || before.size > maxBytes) {
      fail(`${name} must be a non-empty regular file no larger than ${maxBytes} bytes`);
    }
    const bytes = await handle.readFile();
    const after = await handle.stat();
    if (!sameFileStat(before, after) || bytes.length !== after.size) fail(`${name} changed while being read`);
    return bytes;
  } finally {
    await handle.close();
  }
}

export async function resolveDirectory(directory, label, requireEmpty = false) {
  const original = await fs.lstat(directory);
  if (!original.isDirectory() || original.isSymbolicLink()) fail(`${label} must be a real directory`);
  const resolved = await fs.realpath(directory);
  if (requireEmpty && (await fs.readdir(resolved)).length !== 0) fail(`${label} must be empty`);
  return resolved;
}

export async function sourceFileNames(root) {
  const entries = await fs.readdir(root, { withFileTypes: true });
  if (entries.length < 1) fail("Theme package is empty");
  for (const entry of entries) {
    if (!entry.isFile() || entry.isSymbolicLink()) fail(`Theme package contains a non-file entry: ${entry.name}`);
    if (path.basename(entry.name) !== entry.name || CONTROL_PATTERN.test(entry.name)) {
      fail(`Theme package contains an unsafe file name: ${entry.name}`);
    }
  }
  return entries.map((entry) => entry.name).sort();
}
