import fs from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import {
  assertContained,
  assertFingerprint,
  assertReplaceableDirectory,
  assertStoredFingerprint,
  assertThemeId,
  pathExists,
  readRegular,
  readStoredTheme,
  REPLACEMENT_BACKUP_NAME,
  REPLACEMENT_CANDIDATE_NAME,
  REPLACEMENT_COMMIT_NAME,
  REPLACEMENT_COMMIT_TEMP_NAME,
  REPLACEMENT_JOURNAL_NAME,
  REPLACEMENT_TRANSACTION_PREFIX,
  MAX_REPLACEMENT_JOURNAL_BYTES,
} from "./shared.mjs";
import { syncDirectory, writeDurableExclusive } from "./lock.mjs";

// Transaction files are deliberately kept in the managed theme root. Each
// recovery step validates both the journal and the content fingerprints before
// moving anything back into the user-visible library.
function replacementTransactionPath(themesRoot) {
  return path.join(themesRoot, `${REPLACEMENT_TRANSACTION_PREFIX}${randomUUID()}`);
}

export async function createReplacementTransaction(
  themesRoot,
  candidateSource,
  destinationName,
  oldFingerprint,
  newFingerprint,
) {
  const journal = {
    schemaVersion: 1,
    destinationName: assertThemeId(destinationName, "Replacement destination"),
    oldFingerprint: assertFingerprint(oldFingerprint, "Replacement old fingerprint"),
    newFingerprint: assertFingerprint(newFingerprint, "Replacement new fingerprint"),
  };
  const transaction = replacementTransactionPath(themesRoot);
  assertContained(themesRoot, transaction, "Theme replacement transaction");
  await fs.mkdir(transaction, { mode: 0o700 });
  await fs.chmod(transaction, 0o700);
  const candidate = path.join(transaction, REPLACEMENT_CANDIDATE_NAME);
  await fs.rename(candidateSource, candidate);
  await syncDirectory(transaction);
  await assertStoredFingerprint(candidate, journal.newFingerprint, "Theme replacement candidate");
  await writeDurableExclusive(
    path.join(transaction, REPLACEMENT_JOURNAL_NAME),
    Buffer.from(`${JSON.stringify(journal)}\n`, "utf8"),
  );
  await syncDirectory(themesRoot);
  return {
    root: transaction,
    backup: path.join(transaction, REPLACEMENT_BACKUP_NAME),
    candidate,
    committed: path.join(transaction, REPLACEMENT_COMMIT_NAME),
    journal,
  };
}

export async function readReplacementJournal(transaction) {
  const journalPath = path.join(transaction, REPLACEMENT_JOURNAL_NAME);
  const bytes = await readRegular(
    journalPath,
    "Theme replacement journal",
    MAX_REPLACEMENT_JOURNAL_BYTES,
  );
  let journal;
  try { journal = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)); }
  catch { throw new Error("Theme replacement journal is invalid JSON"); }
  if (!journal || typeof journal !== "object" || Array.isArray(journal)) {
    throw new Error("Theme replacement journal must be an object");
  }
  const keys = Object.keys(journal).sort();
  if (keys.join("\0") !== [
    "destinationName", "newFingerprint", "oldFingerprint", "schemaVersion",
  ].join("\0") || journal.schemaVersion !== 1) {
    throw new Error("Theme replacement journal has an unsupported schema");
  }
  return {
    schemaVersion: 1,
    destinationName: assertThemeId(journal.destinationName, "Replacement destination"),
    oldFingerprint: assertFingerprint(journal.oldFingerprint, "Replacement old fingerprint"),
    newFingerprint: assertFingerprint(journal.newFingerprint, "Replacement new fingerprint"),
  };
}

async function replacementEntryState(transaction) {
  await assertReplaceableDirectory(transaction, "Theme replacement transaction");
  const entries = await fs.readdir(transaction, { withFileTypes: true });
  const allowed = new Set([
    REPLACEMENT_JOURNAL_NAME,
    REPLACEMENT_BACKUP_NAME,
    REPLACEMENT_CANDIDATE_NAME,
    REPLACEMENT_COMMIT_NAME,
    REPLACEMENT_COMMIT_TEMP_NAME,
  ]);
  for (const entry of entries) {
    if (!allowed.has(entry.name) || entry.isSymbolicLink()) {
      throw new Error("Theme replacement transaction contains an unexpected entry");
    }
    const directoryEntry = entry.name === REPLACEMENT_BACKUP_NAME || entry.name === REPLACEMENT_CANDIDATE_NAME;
    if (directoryEntry ? !entry.isDirectory() : !entry.isFile()) {
      throw new Error("Theme replacement transaction entry has the wrong type");
    }
  }
  return new Set(entries.map((entry) => entry.name));
}

async function commitReplacementTransaction(transaction) {
  const temporaryMarker = path.join(transaction.root, REPLACEMENT_COMMIT_TEMP_NAME);
  await writeDurableExclusive(temporaryMarker, Buffer.from("dreamskin-theme-replace-commit/1\n", "utf8"));
  await fs.rename(temporaryMarker, transaction.committed);
  await syncDirectory(transaction.root);
}

async function assertReplacementCommitMarker(markerPath, label) {
  const bytes = await readRegular(markerPath, label, 128);
  if (bytes.toString("utf8") !== "dreamskin-theme-replace-commit/1\n") throw new Error(`${label} is invalid`);
}

export async function removeReplacementTransaction(transaction, themesRoot) {
  assertContained(themesRoot, transaction, "Theme replacement transaction cleanup");
  await replacementEntryState(transaction);
  await fs.rm(transaction, { recursive: true, force: false });
  if (await pathExists(transaction)) throw new Error("Theme replacement transaction cleanup was not verified");
  await syncDirectory(themesRoot);
}

async function recoverJournaledReplacement(themesRoot, transaction, journal) {
  const entries = await replacementEntryState(transaction);
  const destination = path.join(themesRoot, journal.destinationName);
  const backup = path.join(transaction, REPLACEMENT_BACKUP_NAME);
  const candidate = path.join(transaction, REPLACEMENT_CANDIDATE_NAME);
  assertContained(themesRoot, destination, "Recovered theme destination");
  const committed = entries.has(REPLACEMENT_COMMIT_NAME);
  const commitTemporary = entries.has(REPLACEMENT_COMMIT_TEMP_NAME);
  const backupExists = entries.has(REPLACEMENT_BACKUP_NAME);
  const candidateExists = entries.has(REPLACEMENT_CANDIDATE_NAME);
  const destinationExists = await pathExists(destination);

  if (committed) {
    if (commitTemporary) throw new Error("Committed theme replacement still contains a temporary commit marker");
    await assertReplacementCommitMarker(path.join(transaction, REPLACEMENT_COMMIT_NAME), "Theme replacement commit marker");
    if (!destinationExists) throw new Error("Committed theme replacement destination is missing");
    await assertStoredFingerprint(destination, journal.newFingerprint, "Committed theme replacement destination");
    if (candidateExists) throw new Error("Committed theme replacement still contains a candidate directory");
    if (backupExists) await assertStoredFingerprint(backup, journal.oldFingerprint, "Theme replacement backup");
    await removeReplacementTransaction(transaction, themesRoot);
    return "committed";
  }

  if (!backupExists) {
    if (!destinationExists || !candidateExists) throw new Error("Prepared theme replacement is missing its recovery copy");
    await assertStoredFingerprint(destination, journal.oldFingerprint, "Prepared theme replacement destination");
    await assertStoredFingerprint(candidate, journal.newFingerprint, "Prepared theme replacement candidate");
    if (commitTemporary) await assertReplacementCommitMarker(path.join(transaction, REPLACEMENT_COMMIT_TEMP_NAME), "Temporary theme replacement commit marker");
    await removeReplacementTransaction(transaction, themesRoot);
    return "unchanged";
  }

  await assertStoredFingerprint(backup, journal.oldFingerprint, "Theme replacement backup");
  if (destinationExists) {
    if (candidateExists) throw new Error("Prepared theme replacement has both a candidate and destination");
    await assertReplaceableDirectory(destination, "Uncommitted theme replacement destination");
    await fs.rename(destination, candidate);
    await syncDirectory(themesRoot);
  }
  await fs.rename(backup, destination);
  await syncDirectory(themesRoot);
  await assertStoredFingerprint(destination, journal.oldFingerprint, "Recovered canonical saved theme");
  if (!(await pathExists(candidate))) throw new Error("Recovered canonical saved theme, but replacement evidence is incomplete");
  await assertStoredFingerprint(candidate, journal.newFingerprint, "Uncommitted theme replacement candidate");
  if (commitTemporary) await assertReplacementCommitMarker(path.join(transaction, REPLACEMENT_COMMIT_TEMP_NAME), "Temporary theme replacement commit marker");
  await removeReplacementTransaction(transaction, themesRoot);
  return "rolled-back";
}

async function recoverLegacyReplacement(themesRoot, transaction) {
  const stored = await readStoredTheme(transaction);
  if (!stored) throw new Error("Legacy theme replacement backup has no valid journal or theme");
  const destinationName = assertThemeId(stored.theme.id, "Legacy replacement destination");
  const destination = path.join(themesRoot, destinationName);
  assertContained(themesRoot, destination, "Legacy replacement destination");
  if (await pathExists(destination)) return "retained-legacy";
  await fs.rename(transaction, destination);
  await syncDirectory(themesRoot);
  await assertStoredFingerprint(destination, stored.fingerprint, "Recovered legacy canonical saved theme");
  return "rolled-back-legacy";
}

async function recoverUnjournaledReplacement(themesRoot, transaction) {
  const stored = await readStoredTheme(transaction);
  if (stored) return recoverLegacyReplacement(themesRoot, transaction);
  const entries = await replacementEntryState(transaction);
  if (entries.size !== 1 || !entries.has(REPLACEMENT_CANDIDATE_NAME)) throw new Error("Theme replacement recovery journal is missing");
  const candidate = path.join(transaction, REPLACEMENT_CANDIDATE_NAME);
  const candidateStored = await readStoredTheme(candidate);
  if (!candidateStored) throw new Error("Unjournaled theme replacement candidate is invalid");
  const destinationName = assertThemeId(candidateStored.theme.id, "Unjournaled replacement destination");
  const destination = path.join(themesRoot, destinationName);
  if (!(await pathExists(destination))) throw new Error("Unjournaled theme replacement has no canonical destination");
  const destinationStored = await readStoredTheme(destination);
  if (!destinationStored || destinationStored.theme.id !== destinationName) throw new Error("Unjournaled theme replacement canonical identity is invalid");
  await removeReplacementTransaction(transaction, themesRoot);
  return "discarded-unprepared";
}

export async function recoverReplacementTransactions(themesRoot) {
  const entries = (await fs.readdir(themesRoot, { withFileTypes: true }))
    .filter((entry) => entry.name.startsWith(REPLACEMENT_TRANSACTION_PREFIX));
  const transactions = [];
  const destinationNames = new Set();
  for (const entry of entries) {
    if (!entry.isDirectory() || entry.isSymbolicLink()) throw new Error("Theme replacement recovery entry must be a real directory");
    const transaction = path.join(themesRoot, entry.name);
    assertContained(themesRoot, transaction, "Theme replacement recovery entry");
    const journalPath = path.join(transaction, REPLACEMENT_JOURNAL_NAME);
    if (!(await pathExists(journalPath))) {
      const stored = await readStoredTheme(transaction) ?? await readStoredTheme(path.join(transaction, REPLACEMENT_CANDIDATE_NAME));
      if (!stored) throw new Error("Theme replacement recovery journal is missing");
      const destinationName = assertThemeId(stored.theme.id, "Legacy replacement destination");
      if (destinationNames.has(destinationName)) throw new Error(`Multiple theme replacement transactions target ${destinationName}`);
      destinationNames.add(destinationName);
      transactions.push({ transaction, journal: null });
      continue;
    }
    const journal = await readReplacementJournal(transaction);
    if (destinationNames.has(journal.destinationName)) throw new Error(`Multiple theme replacement transactions target ${journal.destinationName}`);
    destinationNames.add(journal.destinationName);
    transactions.push({ transaction, journal });
  }
  const recovered = [];
  for (const record of transactions) {
    recovered.push(record.journal
      ? await recoverJournaledReplacement(themesRoot, record.transaction, record.journal)
      : await recoverUnjournaledReplacement(themesRoot, record.transaction));
  }
  return recovered;
}

export { commitReplacementTransaction };
