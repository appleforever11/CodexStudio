import fs from "node:fs/promises";
import { constants as fsConstants } from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { decodeAndValidateSafeCss } from "../../assets/safe-css-validator.mjs";
import { runtimeThemeContentFingerprint } from "../theme-content-fingerprint.mjs";

export const MAX_CONFIG_BYTES = 1024 * 1024;
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
export const MAX_CSS_BYTES = 256 * 1024;
export const MAX_LICENSE_BYTES = 64 * 1024;
export const MAX_MANIFEST_BYTES = 64 * 1024;
export const MAX_SIGNATURE_BYTES = 4 * 1024;
export const OPEN_FLAGS = fsConstants.O_RDONLY | (fsConstants.O_NOFOLLOW ?? 0);
export const REPLACEMENT_TRANSACTION_PREFIX = ".theme-replace-";
export const REPLACEMENT_JOURNAL_NAME = "transaction.json";
export const REPLACEMENT_BACKUP_NAME = "backup";
export const REPLACEMENT_CANDIDATE_NAME = "candidate";
export const REPLACEMENT_COMMIT_NAME = "committed";
export const REPLACEMENT_COMMIT_TEMP_NAME = "commit.tmp";
export const MAX_REPLACEMENT_JOURNAL_BYTES = 16 * 1024;

export function assertContained(rootPath, candidatePath, label) {
  const relative = path.relative(rootPath, candidatePath);
  if (
    relative === ""
    || (!path.isAbsolute(relative) && relative !== ".." && !relative.startsWith(`..${path.sep}`))
  ) return;
  throw new Error(`${label} must stay inside its managed directory`);
}

export async function pathExists(filePath) {
  try {
    await fs.lstat(filePath);
    return true;
  } catch (error) {
    if (error.code === "ENOENT") return false;
    throw error;
  }
}

export async function removeDirectoryVerified(directory, label) {
  if (!(await pathExists(directory))) return;
  await assertReplaceableDirectory(directory, label);
  await fs.rm(directory, { recursive: true, force: true });
  if (await pathExists(directory)) throw new Error(`${label} cleanup was not verified`);
}

export async function assertStoredFingerprint(directory, expectedFingerprint, label) {
  const stored = await readStoredTheme(directory);
  if (!stored) throw new Error(`${label} could not be read after restore`);
  if (stored.fingerprint !== expectedFingerprint) {
    throw new Error(`${label} fingerprint does not match the pre-import record`);
  }
}

export function assertFingerprint(value, label) {
  if (typeof value !== "string" || !/^[0-9a-f]{64}$/.test(value)) {
    throw new Error(`${label} is invalid`);
  }
  return value;
}

export function assertThemeId(value, label) {
  if (typeof value !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(value)
    || value.endsWith(".") || isWindowsReservedPathStem(value)) throw new Error(`${label} is invalid`);
  return value;
}

export function decodeTheme(bytes, label) {
  const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  if (text.includes("\0")) throw new Error(`${label} contains NUL characters`);
  let theme;
  try { theme = JSON.parse(text); } catch { throw new Error(`${label} is not valid JSON`); }
  if (!theme || typeof theme !== "object" || Array.isArray(theme) || theme.schemaVersion !== 1) {
    throw new Error(`${label} must use theme schemaVersion 1`);
  }
  if (typeof theme.image !== "string" || !theme.image || path.basename(theme.image) !== theme.image) {
    throw new Error(`${label} must reference one image beside theme.json`);
  }
  return theme;
}

export async function readRegular(filePath, label, maxBytes) {
  let handle;
  try {
    handle = await fs.open(filePath, OPEN_FLAGS);
  } catch (error) {
    if (error.code === "ELOOP") throw new Error(`${label} must not be a symbolic link`);
    throw error;
  }
  try {
    const stat = await handle.stat();
    if (!stat.isFile() || stat.size < 1 || stat.size > maxBytes) {
      throw new Error(`${label} must be a non-empty regular file no larger than ${maxBytes} bytes`);
    }
    const bytes = await handle.readFile();
    if (bytes.length < 1 || bytes.length > maxBytes) throw new Error(`${label} changed size while it was read`);
    return bytes;
  } finally {
    await handle.close();
  }
}

export function normalizedFingerprint(theme, imageBytes, cssBytes = null, licenseBytes = null) {
  const semanticTheme = { ...theme };
  delete semanticTheme.id;
  const hash = createHash("sha256")
    .update(JSON.stringify(semanticTheme)).update("\0").update(imageBytes);
  if (cssBytes) hash.update("\0theme.css\0").update(cssBytes);
  if (licenseBytes) hash.update("\0LICENSE.txt\0").update(licenseBytes);
  return hash.digest("hex");
}

function updateCanonicalLength(hash, value) {
  const bytes = Buffer.allocUnsafe(8);
  bytes.writeBigUInt64BE(BigInt(value));
  hash.update(bytes);
}

function updateCanonicalString(hash, value) {
  const bytes = Buffer.from(value, "utf8");
  hash.update(Buffer.from([4]));
  updateCanonicalLength(hash, bytes.length);
  hash.update(bytes);
}

function updateCanonicalJsonValue(hash, value) {
  if (value === null) hash.update(Buffer.from([0]));
  else if (value === false) hash.update(Buffer.from([1]));
  else if (value === true) hash.update(Buffer.from([2]));
  else if (typeof value === "number") {
    const bytes = Buffer.allocUnsafe(8);
    bytes.writeDoubleBE(Object.is(value, -0) ? 0 : value);
    hash.update(Buffer.from([3])).update(bytes);
  } else if (typeof value === "string") updateCanonicalString(hash, value);
  else if (Array.isArray(value)) {
    hash.update(Buffer.from([5]));
    updateCanonicalLength(hash, value.length);
    for (const item of value) updateCanonicalJsonValue(hash, item);
  } else if (value && typeof value === "object") {
    const keys = Object.keys(value).sort();
    hash.update(Buffer.from([6]));
    updateCanonicalLength(hash, keys.length);
    for (const key of keys) {
      updateCanonicalString(hash, key);
      updateCanonicalJsonValue(hash, value[key]);
    }
  } else throw new TypeError("Theme JSON contains a value that cannot be canonicalized");
}

function canonicalJsonFingerprint(value) {
  const hash = createHash("sha256").update("dreamskin-canonical-json/1\0", "utf8");
  updateCanonicalJsonValue(hash, value);
  return hash.digest("hex");
}

export function sourceIdFallbackFingerprint(theme, imageBytes, cssBytes = null, licenseBytes = null) {
  const semanticTheme = { ...theme };
  delete semanticTheme.id;
  const hashBytes = (bytes) => createHash("sha256").update(bytes).digest("hex");
  const identity = [
    "dreamskin-source-theme-fallback/1", "theme.json", canonicalJsonFingerprint(semanticTheme),
    "image", hashBytes(imageBytes), "theme.css", cssBytes ? hashBytes(cssBytes) : "absent",
    "LICENSE.txt", licenseBytes ? hashBytes(licenseBytes) : "absent",
  ].join("\0");
  return createHash("sha256").update(identity, "utf8").digest("hex");
}

function isWindowsReservedPathStem(value) {
  const stem = value.split(".", 1)[0];
  return /^(?:CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])$/i.test(stem);
}

export function safeBaseId(value, fingerprint) {
  const candidate = typeof value === "string" ? value.trim() : "";
  if (/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(candidate)
    && !candidate.endsWith(".") && !isWindowsReservedPathStem(candidate)) return candidate;
  if (!candidate) return `import-${fingerprint.slice(0, 24)}`;
  const identity = createHash("sha256").update("dreamskin-source-theme-id/1\0").update(candidate).digest("hex");
  return `import-${identity.slice(0, 24)}`;
}

export function displayName(theme) {
  const value = typeof theme.name === "string" ? theme.name.trim() : "";
  return Array.from(value || "Codex Dream Skin").slice(0, 120).join("");
}

export async function readStoredTheme(directory) {
  try {
    const configBytes = await readRegular(path.join(directory, "theme.json"), "Saved theme config", MAX_CONFIG_BYTES);
    const theme = decodeTheme(configBytes, "Saved theme config");
    const imageBytes = await readRegular(path.join(directory, theme.image), "Saved theme image", MAX_IMAGE_BYTES);
    const [cssBytes, licenseBytes] = await Promise.all([
      readOptionalRegular(path.join(directory, "theme.css"), "Saved theme CSS", MAX_CSS_BYTES),
      readOptionalRegular(path.join(directory, "LICENSE.txt"), "Saved theme license", MAX_LICENSE_BYTES),
    ]);
    if (cssBytes) decodeAndValidateSafeCss(cssBytes);
    const allowedFiles = new Set(["theme.json", theme.image, "theme.css", "LICENSE.txt"]);
    const entries = await fs.readdir(directory, { withFileTypes: true });
    const hasOnlyRuntimeFiles = entries.every((entry) =>
      entry.isFile() && !entry.isSymbolicLink() && allowedFiles.has(entry.name));
    return {
      theme,
      fingerprint: normalizedFingerprint(theme, imageBytes, cssBytes, licenseBytes),
      contentFingerprint: runtimeThemeContentFingerprint(theme, imageBytes, cssBytes),
      hasOnlyRuntimeFiles,
    };
  } catch {
    return null;
  }
}

export async function readOptionalRegular(filePath, label, maxBytes) {
  try { return await readRegular(filePath, label, maxBytes); }
  catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

export async function assertReplaceableDirectory(directory, label) {
  const stat = await fs.lstat(directory);
  if (!stat.isDirectory() || stat.isSymbolicLink()) throw new Error(`${label} must be a real saved-theme directory`);
}

export function legacySuffixOf(value, baseId) {
  if (!baseId || value === baseId) return null;
  const match = value.match(/-([2-9][0-9]*)$/);
  if (!match) return null;
  const suffix = match[1];
  const marker = `-${suffix}`;
  const expectedPrefix = baseId.slice(0, Math.max(0, 80 - marker.length));
  if (value.slice(0, -marker.length) !== expectedPrefix || !/^[2-9][0-9]*$/.test(suffix)) return null;
  const number = Number(suffix);
  return Number.isSafeInteger(number) ? number : null;
}

export function isLegacySuffixRecord(record, baseId) {
  return legacySuffixOf(record.entryName, baseId) !== null && record.themeId === record.entryName;
}

export function processIsAlive(pid) {
  if (!Number.isSafeInteger(pid) || pid < 1) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error.code === "EPERM";
  }
}

export async function readLockOwner(lock) {
  try {
    const bytes = await readRegular(path.join(lock, "owner.json"), "Theme import lock owner", 4096);
    const owner = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
    if (!owner || typeof owner !== "object" || Array.isArray(owner)
      || Object.keys(owner).sort().join("\0") !== "createdAt\0pid\0token"
      || !Number.isSafeInteger(owner.pid) || owner.pid < 1
      || typeof owner.createdAt !== "string" || !Number.isFinite(Date.parse(owner.createdAt))
      || typeof owner.token !== "string" || !/^[0-9a-f-]{36}$/.test(owner.token)) return null;
    return owner;
  } catch {
    return null;
  }
}
