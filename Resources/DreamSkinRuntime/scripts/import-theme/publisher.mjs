import fs from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { decodeAndValidateSafeCss } from "../../assets/safe-css-validator.mjs";
import { runtimeThemeContentFingerprint } from "../theme-content-fingerprint.mjs";
import {
  assertContained,
  assertReplaceableDirectory,
  assertStoredFingerprint,
  decodeTheme,
  displayName,
  isLegacySuffixRecord,
  legacySuffixOf,
  MAX_CONFIG_BYTES,
  MAX_CSS_BYTES,
  MAX_IMAGE_BYTES,
  MAX_LICENSE_BYTES,
  MAX_MANIFEST_BYTES,
  MAX_SIGNATURE_BYTES,
  normalizedFingerprint,
  pathExists,
  readOptionalRegular,
  readRegular,
  readStoredTheme,
  removeDirectoryVerified,
  safeBaseId,
  sourceIdFallbackFingerprint,
} from "./shared.mjs";
import { acquireLock, syncDirectory, writeDurableExclusive } from "./lock.mjs";
import {
  commitReplacementTransaction,
  createReplacementTransaction,
  recoverReplacementTransactions,
  removeReplacementTransaction,
} from "./recovery.mjs";

export async function runImport(stageRoot, themesRoot) {
  const configBytes = await readRegular(
    path.join(stageRoot, "theme.json"),
    "Imported theme config",
    MAX_CONFIG_BYTES,
  );
  const sourceTheme = decodeTheme(configBytes, "Imported theme config");
  const imagePath = path.join(stageRoot, sourceTheme.image);
  assertContained(stageRoot, imagePath, "Imported theme image");
  const imageBytes = await readRegular(imagePath, "Imported theme image", MAX_IMAGE_BYTES);
  const [manifestBytes, cssBytes, licenseBytes, signatureBytes] = await Promise.all([
    readOptionalRegular(path.join(stageRoot, "manifest.json"), "Imported manifest", MAX_MANIFEST_BYTES),
    readOptionalRegular(path.join(stageRoot, "theme.css"), "Imported theme CSS", MAX_CSS_BYTES),
    readOptionalRegular(path.join(stageRoot, "LICENSE.txt"), "Imported theme license", MAX_LICENSE_BYTES),
    readOptionalRegular(path.join(stageRoot, "manifest.sig"), "Imported reserved signature", MAX_SIGNATURE_BYTES),
  ]);
  const packageFormat = manifestBytes ? "official" : "simple";
  if (!cssBytes) throw new Error("New theme imports require non-empty theme.css");
  decodeAndValidateSafeCss(cssBytes);
  const safeCssStatus = "validated";
  const fingerprint = normalizedFingerprint(sourceTheme, imageBytes, cssBytes, licenseBytes);
  const fallbackFingerprint = sourceIdFallbackFingerprint(sourceTheme, imageBytes, cssBytes, licenseBytes);
  const releaseLock = await acquireLock(themesRoot);
  let temporary = "";
  try {
    await recoverReplacementTransactions(themesRoot);
    const entries = await fs.readdir(themesRoot, { withFileTypes: true });
    const records = [];
    const storedById = new Map();
    for (const entry of entries) {
      if (!entry.isDirectory() || entry.name.startsWith(".")) continue;
      const directory = path.join(themesRoot, entry.name);
      const stored = await readStoredTheme(directory);
      if (!stored) continue;
      const record = {
        entryName: entry.name,
        directory,
        stored,
        theme: stored.theme,
        themeId: typeof stored.theme.id === "string" ? stored.theme.id.trim() : "",
        name: displayName(stored.theme),
        fingerprint: stored.fingerprint,
        contentFingerprint: stored.contentFingerprint,
      };
      records.push(record);
      storedById.set(entry.name, record);
    }

    const baseId = safeBaseId(sourceTheme.id, fallbackFingerprint);
    let id = baseId;
    const existingForId = storedById.get(id) ?? null;
    const canonicalFingerprint = existingForId?.entryName === baseId ? existingForId.fingerprint : null;
    const legacySuffixRecords = records
      .filter((record) => isLegacySuffixRecord(record, baseId))
      .sort((a, b) => legacySuffixOf(a.entryName, baseId) - legacySuffixOf(b.entryName, baseId));
    const exactRecords = records.filter((record) => record.fingerprint === fingerprint);
    const exactCanonical = exactRecords.find((record) => record.entryName === baseId) ?? null;
    const exactLegacy = exactRecords.filter((record) => isLegacySuffixRecord(record, baseId));
    const exactUnrelated = exactRecords.find((record) =>
      record.entryName !== baseId && !isLegacySuffixRecord(record, baseId));
    if (!existingForId && exactUnrelated && exactLegacy.length === 0) {
      return {
        status: "duplicate",
        id: exactUnrelated.entryName,
        name: exactUnrelated.name,
        renamed: false,
        nameCollision: false,
        packageFormat,
        safeCssStatus,
        signatureIgnored: Boolean(signatureBytes),
        contentFingerprint: exactUnrelated.contentFingerprint,
      };
    }
    const legacyCleanupRecords = legacySuffixRecords.filter((record) =>
      record.entryName !== baseId && record.fingerprint === fingerprint && record.stored.hasOnlyRuntimeFiles);
    if (exactCanonical && legacyCleanupRecords.length === 0) {
      return {
        status: "duplicate",
        id: exactCanonical.entryName,
        name: exactCanonical.name,
        renamed: false,
        nameCollision: false,
        packageFormat,
        safeCssStatus,
        signatureIgnored: Boolean(signatureBytes),
        contentFingerprint: exactCanonical.contentFingerprint,
      };
    }

    const baseDestination = path.join(themesRoot, id);
    const basePathExists = await pathExists(baseDestination);
    if (basePathExists) {
      const baseStat = await fs.lstat(baseDestination);
      if (!baseStat.isDirectory() || baseStat.isSymbolicLink()) {
        throw new Error("Existing saved theme path is not a directory; refusing replacement");
      }
      if (!existingForId || existingForId.themeId !== baseId) {
        throw new Error("Existing saved theme identity could not be confirmed for replacement");
      }
    }
    const replaceExisting = basePathExists;
    if (!replaceExisting) {
      let suffix = 2;
      while (await pathExists(path.join(themesRoot, id))) {
        const marker = `-${suffix}`;
        id = `${baseId.slice(0, 80 - marker.length)}${marker}`;
        suffix += 1;
      }
    }
    const renamed = id !== (typeof sourceTheme.id === "string" ? sourceTheme.id.trim() : "");
    const theme = { ...sourceTheme, id };
    const name = displayName(theme);
    const contentFingerprint = runtimeThemeContentFingerprint(theme, imageBytes, cssBytes);
    const destination = path.join(themesRoot, id);
    assertContained(themesRoot, destination, "Imported theme destination");

    temporary = await fs.mkdtemp(path.join(themesRoot, ".theme-import-"));
    await fs.chmod(temporary, 0o700);
    await writeDurableExclusive(path.join(temporary, theme.image), imageBytes);
    await writeDurableExclusive(
      path.join(temporary, "theme.json"),
      Buffer.from(`${JSON.stringify(theme, null, 2)}\n`, "utf8"),
    );
    await writeDurableExclusive(path.join(temporary, "theme.css"), cssBytes);
    if (licenseBytes) await writeDurableExclusive(path.join(temporary, "LICENSE.txt"), licenseBytes);

    let replacementTransaction = null;
    let publishedDestination = false;
    if (replaceExisting) {
      replacementTransaction = await createReplacementTransaction(
        themesRoot, temporary, id, canonicalFingerprint, fingerprint,
      );
      temporary = "";
    }
    const publishSource = replacementTransaction?.candidate ?? temporary;
    try {
      if (replacementTransaction) {
        await fs.rename(destination, replacementTransaction.backup);
        await syncDirectory(themesRoot);
        await syncDirectory(replacementTransaction.root);
      }
      await fs.rename(publishSource, destination);
      publishedDestination = true;
      if (!replacementTransaction) temporary = "";
      await syncDirectory(themesRoot);
      const published = await readStoredTheme(destination);
      if (!published || published.fingerprint !== fingerprint) {
        throw new Error("Published theme content does not match the validated import payload");
      }
      if (replacementTransaction) await commitReplacementTransaction(replacementTransaction);
    } catch (error) {
      const rollbackErrors = [];
      if (publishedDestination) {
        try {
          if (replacementTransaction) {
            if (await pathExists(replacementTransaction.candidate)) throw new Error("replacement candidate already exists");
            await fs.rename(destination, replacementTransaction.candidate);
          } else if (await pathExists(destination)) {
            await assertReplaceableDirectory(destination, "Published theme rollback target");
            const quarantine = path.join(themesRoot, `.theme-failed-${randomUUID()}`);
            assertContained(themesRoot, quarantine, "Failed theme quarantine");
            await fs.rename(destination, quarantine);
            await removeDirectoryVerified(quarantine, "Failed theme quarantine");
          }
          if (await pathExists(destination)) throw new Error("published destination remains");
        } catch (rollbackError) {
          rollbackErrors.push(`${destination}: ${rollbackError.message}`);
        }
      }
      if (replacementTransaction) {
        try {
          const backupExists = await pathExists(replacementTransaction.backup);
          const destinationExists = await pathExists(destination);
          if (backupExists) {
            if (destinationExists) throw new Error("new destination remains");
            await fs.rename(replacementTransaction.backup, destination);
            await syncDirectory(themesRoot);
          }
          if (await pathExists(replacementTransaction.backup)) throw new Error("replacement backup remains after restore");
          if (!(await pathExists(destination))) throw new Error("original directory was not restored");
          await assertStoredFingerprint(destination, canonicalFingerprint, "Canonical saved theme");
          await removeReplacementTransaction(replacementTransaction.root, themesRoot);
        } catch (rollbackError) {
          rollbackErrors.push(`${destination}: ${rollbackError.message}`);
        }
      } else {
        try {
          if (await pathExists(destination)) throw new Error("unexpected destination remains after rollback");
        } catch (rollbackError) {
          rollbackErrors.push(`${destination}: ${rollbackError.message}`);
        }
      }
      if (rollbackErrors.length > 0) {
        throw new Error(`${error.message}; import rollback was not verified: ${rollbackErrors.join("; ")}`);
      }
      throw error;
    }

    let cleanupWarning = null;
    const cleanupErrors = [];
    if (replacementTransaction) {
      try { await removeReplacementTransaction(replacementTransaction.root, themesRoot); }
      catch (error) { cleanupErrors.push(error.message); }
    }
    for (const record of legacyCleanupRecords) {
      if (record.entryName === id) continue;
      const cleanupBackup = path.join(themesRoot, `.theme-legacy-cleanup-${randomUUID()}`);
      try {
        await assertReplaceableDirectory(record.directory, "Legacy saved theme duplicate");
        assertContained(themesRoot, cleanupBackup, "Legacy saved theme cleanup backup");
        await fs.rename(record.directory, cleanupBackup);
        await removeDirectoryVerified(cleanupBackup, "Legacy duplicate cleanup backup");
      } catch (error) {
        cleanupErrors.push(error.message);
      }
    }
    if (cleanupErrors.length > 0) {
      cleanupWarning = `Imported theme backup cleanup was not verified: ${cleanupErrors.join("; ")}`;
    }
    return {
      status: "imported",
      id,
      name,
      renamed,
      replaced: replaceExisting,
      nameCollision: records.some((record) =>
        record.name === name && record.entryName !== id
        && !legacyCleanupRecords.some((legacy) => legacy.entryName === record.entryName)),
      packageFormat,
      safeCssStatus,
      signatureIgnored: Boolean(signatureBytes),
      contentFingerprint,
      cleanupWarning,
    };
  } finally {
    if (temporary) await fs.rm(temporary, { recursive: true, force: true }).catch(() => {});
    await releaseLock();
  }
}
