// Official package manifest and payload contract validation.

import {
  KEY_ID_PATTERN,
  LICENSE_PATTERN,
  MANIFEST_REQUIRED,
  PAYLOAD_MEDIA,
  PROVENANCE_CONTROL_PATTERN,
  PUBLISHER_ID_PATTERN,
  THEME_ID_PATTERN,
} from "./theme-package-contract.mjs";
import {
  assertExactKeys,
  assertObject,
  assertString,
  assertStringSet,
  expectedLimit,
  fail,
  parseSemver,
  compareSemver,
} from "./theme-package-primitives.mjs";
import { validateTimestamp } from "./theme-package-theme-validation.mjs";

export function validateManifest(value, platform, clientVersion) {
  const manifest = assertObject(value, "manifest.json");
  assertExactKeys(manifest, MANIFEST_REQUIRED, ["keyId"], "manifest.json");
  if (manifest.packageVersion !== 1) fail("manifest.json must use packageVersion 1");
  if (manifest.skinApiVersion !== 1) fail("manifest.json requires an unsupported Skin API version");
  assertString(manifest.themeId, "manifest.themeId", {
    min: 3,
    max: 64,
    pattern: THEME_ID_PATTERN,
    controls: null,
  });
  parseSemver(manifest.version, "manifest.version");
  const requiredClient = parseSemver(manifest.minClientVersion, "manifest.minClientVersion");
  const installedClient = parseSemver(clientVersion, "client version");
  if (compareSemver(requiredClient, installedClient) > 0) {
    fail(`Theme requires Dream Skin ${manifest.minClientVersion} or newer; installed version is ${clientVersion}`);
  }
  const platforms = assertStringSet(manifest.platforms, "manifest.platforms", {
    min: 1,
    max: 2,
    allowed: new Set(["macos", "windows"]),
  });
  if (!platforms.has(platform)) fail(`Theme package does not support ${platform}`);
  const capabilities = assertStringSet(manifest.capabilities, "manifest.capabilities", {
    min: 1,
    max: 3,
    allowed: new Set(["background", "tokens", "safe-css"]),
  });

  const publisher = assertObject(manifest.publisher, "manifest.publisher");
  assertExactKeys(publisher, ["id", "displayName"], [], "manifest.publisher");
  assertString(publisher.id, "manifest.publisher.id", {
    min: 1,
    max: 64,
    pattern: PUBLISHER_ID_PATTERN,
    controls: null,
  });
  assertString(publisher.displayName, "manifest.publisher.displayName", { min: 1, max: 80 });
  assertString(manifest.license, "manifest.license", {
    min: 1,
    max: 64,
    pattern: LICENSE_PATTERN,
    controls: null,
  });
  const provenance = assertObject(manifest.provenance, "manifest.provenance");
  assertExactKeys(provenance, ["aiGenerated", "summary"], [], "manifest.provenance");
  if (typeof provenance.aiGenerated !== "boolean") fail("manifest.provenance.aiGenerated must be boolean");
  assertString(provenance.summary, "manifest.provenance.summary", {
    min: 1,
    max: 500,
    controls: PROVENANCE_CONTROL_PATTERN,
  });
  if (manifest.keyId !== undefined) {
    assertString(manifest.keyId, "manifest.keyId", {
      min: 1,
      max: 64,
      pattern: KEY_ID_PATTERN,
      controls: null,
    });
  }
  validateTimestamp(manifest.createdAt);

  if (!Array.isArray(manifest.files) || manifest.files.length < 2 || manifest.files.length > 8) {
    fail("manifest.files must contain between 2 and 8 entries");
  }
  const files = new Map();
  for (let index = 0; index < manifest.files.length; index += 1) {
    const entry = assertObject(manifest.files[index], `manifest.files[${index}]`);
    assertExactKeys(entry, ["path", "mediaType", "bytes", "sha256"], [], `manifest.files[${index}]`);
    if (typeof entry.path !== "string" || !PAYLOAD_MEDIA.has(entry.path)) {
      fail(`manifest.files[${index}].path is unsupported`);
    }
    if (files.has(entry.path)) fail(`manifest.files repeats ${entry.path}`);
    if (entry.mediaType !== PAYLOAD_MEDIA.get(entry.path)) {
      fail(`manifest.files mediaType does not match ${entry.path}`);
    }
    const limit = expectedLimit(entry.path);
    if (!Number.isSafeInteger(entry.bytes) || entry.bytes < 1 || entry.bytes > limit) {
      fail(`manifest.files bytes for ${entry.path} exceed its limit`);
    }
    if (typeof entry.sha256 !== "string" || !/^[0-9a-f]{64}$/.test(entry.sha256)) {
      fail(`manifest.files SHA-256 for ${entry.path} is invalid`);
    }
    files.set(entry.path, entry);
  }
  const backgrounds = [...files.keys()].filter((name) => BACKGROUND_MEDIA.has(name));
  if (!files.has("theme.json") || backgrounds.length !== 1) {
    fail("manifest.files must contain theme.json and exactly one background file");
  }
  if (files.has("theme.css") !== capabilities.has("safe-css")) {
    fail("theme.css presence must match the safe-css capability");
  }
  if (!files.has("theme.css")) {
    fail("New official theme imports require theme.css and the safe-css capability");
  }
  return { manifest, files, background: backgrounds[0] };
}
