// Stable payload reads, media checks, and simple/official validators.

import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { decodeAndValidateSafeCss } from "./safe-css-validator.mjs";
import {
  BACKGROUND_MEDIA,
  CONTROL_PATTERN,
  LIMITS,
  PACKAGE_FILES,
  PAYLOAD_MEDIA,
} from "./theme-package-contract.mjs";
import {
  assertObject,
  decodeJson,
  expectedLimit,
  fail,
  readStableFile,
} from "./theme-package-primitives.mjs";
import { validateOfficialTheme } from "./theme-package-theme-validation.mjs";
import { validateManifest } from "./theme-package-manifest-validation.mjs";

export function setsEqual(left, right) {
  return left.size === right.size && [...left].every((value) => right.has(value));
}

export function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

export function detectedImageMedia(bytes) {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return "image/jpeg";
  }
  const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length >= png.length && png.every((byte, index) => bytes[index] === byte)) {
    return "image/png";
  }
  if (
    bytes.length >= 12
    && bytes.subarray(0, 4).toString() === "RIFF"
    && bytes.subarray(8, 12).toString() === "WEBP"
  ) return "image/webp";
  return "";
}

export async function validateOfficial(root, names, platform, clientVersion) {
  for (const name of names) {
    if (!PACKAGE_FILES.has(name)) fail(`Official theme package contains unregistered file ${name}`);
  }
  if (!names.includes("manifest.json")) fail("Official theme package is missing manifest.json");
  const bytes = new Map();
  for (const name of names) bytes.set(name, await readStableFile(root, name, expectedLimit(name)));
  const { manifest, files, background } = validateManifest(
    decodeJson(bytes.get("manifest.json"), "manifest.json"),
    platform,
    clientVersion,
  );
  const actualPayload = new Set(names.filter((name) => name !== "manifest.json" && name !== "manifest.sig"));
  if (!setsEqual(actualPayload, new Set(files.keys()))) {
    fail("ZIP payload files do not exactly match manifest.files");
  }
  for (const [name, entry] of files) {
    const data = bytes.get(name);
    if (!data) fail(`manifest.files declares missing file ${name}`);
    if (data.length !== entry.bytes) fail(`${name} byte length does not match manifest.json`);
    if (sha256(data) !== entry.sha256) fail(`${name} SHA-256 does not match manifest.json`);
  }
  const theme = validateOfficialTheme(decodeJson(bytes.get("theme.json"), "theme.json"));
  if (manifest.themeId !== theme.id) fail("manifest.themeId does not match theme.json id");
  if (theme.image !== background) fail("theme.json image does not match the manifest background file");
  if (detectedImageMedia(bytes.get(background)) !== BACKGROUND_MEDIA.get(background)) {
    fail(`${background} content does not match its extension and mediaType`);
  }
  decodeAndValidateSafeCss(bytes.get("theme.css"));
  return {
    format: "official",
    image: background,
    safeCssStatus: "validated",
    signatureIgnored: bytes.has("manifest.sig"),
    bytes,
  };
}

export async function validateSimple(root, names) {
  if (names.length !== 3 || !names.includes("theme.json") || !names.includes("theme.css")) {
    fail("Local simplified ZIP must contain exactly theme.json, theme.css, and its image");
  }
  const themeBytes = await readStableFile(root, "theme.json", LIMITS.simpleTheme);
  const theme = assertObject(decodeJson(themeBytes, "theme.json"), "theme.json");
  if (theme.schemaVersion !== 1 || typeof theme.image !== "string" || !theme.image) {
    fail("Local simplified theme must use schemaVersion 1 and name an image");
  }
  if (
    path.basename(theme.image) !== theme.image
    || CONTROL_PATTERN.test(theme.image)
    || !/\.(?:png|jpe?g|webp)$/i.test(theme.image)
    || !names.includes(theme.image)
  ) fail("Local simplified theme image must be beside theme.json");
  const [imageBytes, cssBytes] = await Promise.all([
    readStableFile(root, theme.image, LIMITS.image),
    readStableFile(root, "theme.css", LIMITS.css),
  ]);
  const expectedMedia = /\.png$/i.test(theme.image)
    ? "image/png"
    : /\.webp$/i.test(theme.image) ? "image/webp" : "image/jpeg";
  if (detectedImageMedia(imageBytes) !== expectedMedia) {
    fail(`${theme.image} content does not match its extension`);
  }
  decodeAndValidateSafeCss(cssBytes);
  return {
    format: "simple",
    image: theme.image,
    safeCssStatus: "validated",
    signatureIgnored: false,
    bytes: new Map([
      ["theme.json", themeBytes],
      [theme.image, imageBytes],
      ["theme.css", cssBytes],
    ]),
  };
}
